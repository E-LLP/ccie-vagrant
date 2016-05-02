#!/bin/sh

#
# This script is meant for quick & easy install via:
#   'curl -sSL https://get.replicated.com/ | sudo sh'
# or:
#   'wget -qO- https://get.replicated.com/ | sudo sh'
#

SCRIPT=$(cat <<"%INSTALL_SCRIPT_END%"

set -e

PROXY_ADDRESS=(%proxy_address%)
PRIVATE_ADDRES="192.168.205.10"
SKIP_DOCKER_INSTALL=(%skip_docker_install%)
READ_TIMEOUT="(%read_timeout%)"
PINNED_DOCKER_VERSION='1.10.2'

command_exists() {
    command -v "$@" > /dev/null 2>&1
}

install_alias_file() {
    if [ -n "$bashrc_file" ]; then
        if ! grep -q "/etc/replicated.alias" "$bashrc_file"; then
            cat >> "$bashrc_file" <<- EOM

if [ -f /etc/replicated.alias ]; then
    . /etc/replicated.alias
fi
EOM
        fi
    fi
}

FOUND_DOCKER_VER=
check_docker_presence() {
    handle_docker_downgrade() {
        printf "\nThe installed version of Docker (%s) may not be compatible with this installer.\nThe recommended version is %s" "$FOUND_DOCKER_VER" "$PINNED_DOCKER_VERSION"
        printf "\nDo you want to proceed anyway? (y/N) "
        set +e
        read $READ_TIMEOUT allow < /dev/tty
        set -e
        if [[ "$allow" = "y" || "$allow" = "Y" ]]; then
            SKIP_DOCKER_INSTALL=1
        else
            exit 1
        fi
    }

    handle_docker_upgrade() {
        printf "\nThis installer will upgrade your current version of Docker (%s) to the minimum required version: %s" "$FOUND_DOCKER_VER" "$PINNED_DOCKER_VERSION"
        printf "\nDo you want to allow this? (Y/n) "
        set +e
        read $READ_TIMEOUT allow < /dev/tty
        set -e
        if [[ "$allow" != "y" && "$allow" != "Y" && -n "$allow" ]]; then
            printf "\nPlease manually upgrade your current version of Docker to the minimum required version: %s\n" "$PINNED_DOCKER_VERSION"
            exit 1
        fi
    }

    if [[ -x /usr/bin/docker ]]; then
        # Amazon Linux may come with Docker pre-installed.
        # If so, we don't want to show any prompts.
        if [[ "$lsb_dist" = "amzn" ]]; then
            SKIP_DOCKER_INSTALL=1
            return
        fi

        OLD_IFS="$IFS" && IFS=. && set -- $PINNED_DOCKER_VERSION && IFS="$OLD_IFS"
        pinned_major=$1
        pinned_minor=$2
        pinned_patch=$3

        FOUND_DOCKER_VER=$(/usr/bin/docker -v | awk '{gsub(/,/, "", $3); print $3}')
        OLD_IFS="$IFS" && IFS=. && set -- $FOUND_DOCKER_VER && IFS="$OLD_IFS"
        foundver_major=$1
        foundver_minor=$2
        foundver_patch=$3

        if [[ $foundver_minor -eq $pinned_minor ]]; then
            if [[ $foundver_patch -gt $pinned_patch ]]; then
                handle_docker_downgrade
            elif [[ $foundver_patch -lt $pinned_patch ]]; then
                handle_docker_upgrade
            else
                # The system has the exact pinned version installed.
                # No need to run the Docker install script.
                SKIP_DOCKER_INSTALL=1
            fi
        elif [[ $foundver_minor -gt $pinned_minor ]]; then
            handle_docker_downgrade
        elif [[ $foundver_minor -lt $pinned_minor ]]; then
            handle_docker_upgrade
        fi
    fi
}

install_docker_deb() {
    curl -sSL https://get.docker.com | sed $'s/$sh_c \'sleep 3; apt-get update; apt-get install -y -q docker-engine\'/$sh_c "sleep 3; apt-get update; apt-get install -y -q docker-engine=${PINNED_DOCKER_VERSION}-0~${dist_version}"/' > /tmp/install_docker.sh
    export PINNED_DOCKER_VERSION
    sh /tmp/install_docker.sh < /dev/null
}

install_docker_rpm() {
    curl -sSL https://get.docker.com | sed "s/yum -y -q install docker-engine/yum -y -q install docker-engine-${PINNED_DOCKER_VERSION}/" > /tmp/install_docker.sh
    export PINNED_DOCKER_VERSION
    sh /tmp/install_docker.sh < /dev/null
}

check_docker_driver() {
    driver=$(docker info | grep 'Execution Driver' | awk '{print $3}' | awk -F- '{print $1}')
    if [ "$driver" = "lxc" ]; then
        echo >&2 "Error: the running Docker daemon is configured to use the '${driver}' execution driver."
        echo >&2 "This installer only supports the 'native' driver (AKA 'libcontainer')."
        echo >&2 "Check your Docker options."
        exit 1
    fi
}

ask_for_ip() {
    local count=0
    local regex="^[[:digit:]]+: ([^[:space:]]+)[[:space:]]+[[:alnum:]]+ ([[:digit:].]+)"
    local iface_names
    local iface_addrs
    local line
    while read -r line; do
        let "count += 1"
        [[ $line =~ $regex ]]
        iface_names[$((count-1))]=${BASH_REMATCH[1]}
        iface_addrs[$((count-1))]=${BASH_REMATCH[2]}
    done <<< "$(ip -4 -o addr)"
    if [[ $count -eq 0 ]]; then
        printf "The installer couldn't discover any valid network interfaces on this machine.\n"
        printf "Check your network configuration and re-run this script again.\n"
        printf "If you want to skip this discovery process, pass the 'local_address' arg to this script, e.g. 'sudo ./install.sh local_address=1.2.3.4'\n"
        exit 1
    elif [[ $count -eq 1 ]]; then
        PRIVATE_ADDRESS=${iface_addrs[1]}
        printf "\nThe installer will use network interface '%s' (with IP address '%s')\n\n" ${iface_names[1]} ${iface_addrs[1]}
        return
    fi
    printf "The installer was unable to automatically detect the private IP address of this machine.\n"
    printf "Please choose one of the following network interfaces:\n"
    printf "[0] default: unspecified\n"
    for i in $(seq 0 $((count-1))); do
        printf "[%d] %-5s\t%s\n" $((i+1)) ${iface_names[$i]} ${iface_addrs[$i]}
    done
    while true; do
        printf "Enter desired number (0-%d): " $count
        set +e
        if [[ -n "$READ_TIMEOUT" ]]; then
            read -t 60 chosen < /dev/tty
        else
            read chosen < /dev/tty
        fi
        set -e
        if [[ -z "$chosen" || $chosen -eq 0 ]]; then
            return
        fi
        if [[ $chosen -gt 0 && $chosen -le $count ]]; then
            PRIVATE_ADDRESS=${iface_addrs[$((chosen-1))]}
            printf "\nThe installer will use network interface '%s' (with IP address '%s).\n\n" ${iface_names[$((chosen-1))]} $PRIVATE_ADDRESS
            return
        fi
    done
}

discover_ip() {
    if [[ -n "$PRIVATE_ADDRESS" ]]; then
        return
    fi

    echo "Checking network configuration..."
    local gce_test=$(curl --connect-timeout 10 -s -o /dev/null -w '%{http_code}' -H 'Metadata-Flavor: Google' http://169.254.169.254/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)
    if [[ "$gce_test" != "200" ]]; then
        echo "Analyzing network configuration..."
        local ec2_test=$(curl --connect-timeout 10 -s -o /dev/null -w '%{http_code}' http://169.254.169.254/latest/meta-data/public-ipv4)
        if [[ "$ec2_test" != "200" ]]; then
            ask_for_ip
        fi
    fi
}

ask_for_proxy() {
    printf "\nDoes this machine require a proxy to access the Internet? (y/N) "
    set +e
    read $READ_TIMEOUT wants_proxy < /dev/tty
    set -e
    if [[ "$wants_proxy" != "y" && "$wants_proxy" != "Y" ]]; then
        return
    fi

    printf "Enter desired HTTP proxy address: "
    set +e
    read $READ_TIMEOUT chosen < /dev/tty
    set -e
    if [[ -n "$chosen" ]]; then
        PROXY_ADDRESS="$chosen"
        printf "\nThe installer will use the proxy at '%s'.\n\n" "$PROXY_ADDRESS"
    fi
}

discover_proxy() {
    if [[ -n "$PROXY_ADDRESS" ]]; then
        return
    fi

    if [[ -n $HTTP_PROXY ]]; then
        PROXY_ADDRESS="$HTTP_PROXY"
        printf "\nThe installer will use the proxy at '%s'. (imported from env var 'HTTP_PROXY')\n\n" $PROXY_ADDRESS
        return
    elif [[ -n $http_proxy ]]; then
        PROXY_ADDRESS="$http_proxy"
        printf "\nThe installer will use the proxy at '%s'. (imported from env var 'http_proxy')\n\n" $PROXY_ADDRESS
        return
    elif [[ -n $HTTPS_PROXY ]]; then
        PROXY_ADDRESS="$HTTPS_PROXY"
        printf "\nThe installer will use the proxy at '%s'. (imported from env var 'HTTPS_PROXY')\n\n" $PROXY_ADDRESS
        return
    elif [[ -n $https_proxy ]]; then
        PROXY_ADDRESS="$https_proxy"
        printf "\nThe installer will use the proxy at '%s'. (imported from env var 'https_proxy')\n\n" $PROXY_ADDRESS
        return
    fi

    ask_for_proxy
}

create_replicated_conf() {
    if [[ ! -f /etc/replicated.conf ]]; then
        printf "{\n" > /etc/replicated.conf

        if [[ $nodocker -eq 1 ]]; then
            printf '\t"AgentBootstrapInstallsDocker": false,\n' >> /etc/replicated.conf
        fi
        if [[ -n "$PROXY_ADDRESS" ]]; then
            printf "\t\"HttpProxy\": \"%s\",\n" "$PROXY_ADDRESS" >> /etc/replicated.conf
        fi
        if [[ -n "$PRIVATE_ADDRESS" ]]; then
            printf "\t\"LocalAddress\": \"%s\",\n" "$PRIVATE_ADDRESS" >> /etc/replicated.conf
        fi
        printf '\t"ReleaseChannel": "stable"\n' >> /etc/replicated.conf
        printf '}\n' >> /etc/replicated.conf
    fi
}

outro() {
    if [[ -z "$PRIVATE_ADDRESS" ]]; then
        PRIVATE_ADDRESS="<this_server_address>"
    fi

    printf "\nTo continue the installation, visit the following URL in your browser: https://%s:8800\n\n" "$PRIVATE_ADDRESS"
}

do_install() {
    case "$(uname -m)" in
        *64)
            ;;
        *)
            echo >&2 'Error: you are not using a 64bit platform.'
            echo >&2 'This installer currently only supports 64bit platforms.'
            exit 1
            ;;
    esac

    user="$(id -un 2>/dev/null || true)"

    if [[ "$user" != "root" ]]; then
        echo >&2 "This script requires admin privileges. Please re-run it as root."
        exit 1
    fi

    if [ -f /etc/bashrc ]; then
        bashrc_file="/etc/bashrc"
    elif [ -f /etc/bash.bashrc ]; then
        bashrc_file="/etc/bash.bashrc"
    else
        echo >&2 'No global bashrc file found.  Admin command aliasing will be disabled.'
    fi

    lsb_dist=''
    if [ -r /etc/os-release ]; then
        _dist="$(. /etc/os-release && echo "$ID")"
        _dist="$(echo "$_dist" | tr '[:upper:]' '[:lower:]')"
        _version="$(. /etc/os-release && echo "$VERSION_ID")"
        case "$_dist" in
            ubuntu)
                oIFS="$IFS"; IFS=.; set -- $_version; IFS="$oIFS";
                [ $1 -ge 10 ] && lsb_dist=$_dist
                ;;
            debian)
                oIFS="$IFS"; IFS=.; set -- $_version; IFS="$oIFS";
                [ $1 -ge 7 ] && lsb_dist=$_dist
                ;;
            fedora)
                oIFS="$IFS"; IFS=.; set -- $_version; IFS="$oIFS";
                [ $1 -ge 20 ] && lsb_dist=$_dist
                ;;
            rhel)
                oIFS="$IFS"; IFS=.; set -- $_version; IFS="$oIFS";
                [ $1 -ge 7 ] && lsb_dist=$_dist
                ;;
            centos)
                oIFS="$IFS"; IFS=.; set -- $_version; IFS="$oIFS";
                [ $1 -ge 7 ] && lsb_dist=$_dist
                ;;
            amzn)
                [ "$_version" = "2016.03" ] || \
                [ "$_version" = "2015.03" ] || [ "$_version" = "2015.09" ] || \
                [ "$_version" = "2014.03" ] || [ "$_version" = "2014.09" ] && \
                lsb_dist=$_dist
                ;;
        esac
    elif grep -q "Amazon.*2014\.03" /etc/system-release; then
        lsb_dist=amzn
    fi

    cat > /etc/logrotate.d/replicated  <<-EOF
/var/log/replicated/*.log {
  size 500k
  rotate 4
  nocreate
  compress
  notifempty
  missingok
}
EOF

    # Check docker version
    if [ $SKIP_DOCKER_INSTALL -eq 0 ]; then
        # Double-check...
        check_docker_presence
    fi

    discover_ip

    case "$lsb_dist" in
        fedora|rhel|centos|amzn)
            yum install -y gpg

            gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 822819BB
            gpg --export -a 822819BB > /tmp/replicated_pub.asc
            rpm --import /tmp/replicated_pub.asc

            cat > /etc/yum.repos.d/replicated.repo <<-EOF
[replicated]
name=Replicated Repository
baseurl=https://get.replicated.com/yum/stable
EOF

            # Enable secondary repos and install deps.
            yum install -y yum-utils
            case "$lsb_dist" in
                amzn)
                    yum-config-manager --enable epel/x86_64
                    ;;
                rhel)
                    set +e
                    subscription-manager repos --enable rhel-7-server-extras-rpms
                    if [[ $? -ne 0 ]]; then
                        yum-config-manager --enable rhui-REGION-rhel-server-extras
                    fi
                    set -e
                    ;;
            esac
            yum makecache
            yum install -y python-hashlib curl

            if [ $SKIP_DOCKER_INSTALL -eq 0 ]; then
                case "$lsb_dist" in
                    amzn)
                        yum -y install docker
                        ;;
                    *)
                        install_docker_rpm
                        ;;
                esac
                check_docker_driver
            fi

            create_replicated_conf

            yum install -y replicated replicated-ui

            case "$lsb_dist" in
                amzn)
                    # Amazon Linux uses upstart.
                    # Except for Docker, which uses sysv init
                    service docker start
                    start replicated
                    start replicated-ui
                    ;;
                *)
                    systemctl enable docker
                    systemctl enable replicated
                    systemctl enable replicated-ui

                    printf "\nStarting services. Please wait, this may take a few minutes...\n"

                    systemctl start docker
                    systemctl start replicated
                    systemctl start replicated-ui
                    ;;
            esac

            install_alias_file

            outro

            exit 0
            ;;

        ubuntu|debian)
            if [ $SKIP_DOCKER_INSTALL -eq 0 ]; then
                install_docker_deb
                check_docker_driver
            fi

            create_replicated_conf

            export DEBIAN_FRONTEND=noninteractive

            did_apt_get_update=
            apt_get_update() {
                if [ -z "$did_apt_get_update" ]; then
                    apt-get update
                    did_apt_get_update=1
                fi
            }

            if [ ! -e /usr/lib/apt/methods/https ]; then
                apt_get_update
                apt-get install -y apt-transport-https
            fi

            apt_get_update
            apt-get install -y curl

            echo "deb https://get.replicated.com/apt all stable" | sudo tee /etc/apt/sources.list.d/replicated.list
            apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 68386EDB2C8B75CA615A8C985D4781862AFFAC40

            apt-get update # forced
            apt-get install -y replicated replicated-ui

            if command_exists systemctl; then
                systemctl enable docker
                systemctl enable replicated
                systemctl enable replicated-ui
            fi

            install_alias_file

            outro

            exit 0
            ;;
    esac

    cat >&2 <<'EOF'

  Either your platform is not easily detectable, is not supported by this
  installer script, or does not yet have a package for Replicated.
  Please visit the following URL for more detailed installation instructions:

    http://docs.replicated.com/docs/installing-replicated

EOF
    exit 1
}

do_install "$@"

%INSTALL_SCRIPT_END%
)

PRIVATE_ADDRESS="192.168.205.10"
SKIP_DOCKER_INSTALL=0
READ_TIMEOUT="-t 20"

while [ "$1" != "" ]; do
    PARAM=`echo "$1" | awk -F= '{print $1}'`
    VALUE=`echo "$1" | awk -F= '{print $2}'`
    case $PARAM in
        http-proxy|http_proxy)
            PROXY_ADDRESS=$VALUE
            ;;
        local-address|local_address)
            PRIVATE_ADDRESS=$VALUE
            ;;
        no-docker|no_docker)
            SKIP_DOCKER_INSTALL=1
            ;;
        no-auto|no_auto)
            READ_TIMEOUT=
            ;;
        *)
            echo "ERROR: unknown parameter \"$PARAM\""
            exit 1
            ;;
    esac
    shift
done

SCRIPT=$(echo "$SCRIPT" | sed 's|(%proxy_address%)|'"$PROXY_ADDRESS"'|' | sed 's|(%private_address%)|'"$PRIVATE_ADDRESS"'|' | sed 's|(%skip_docker_install%)|'"$SKIP_DOCKER_INSTALL"'|' | sed 's|(%read_timeout%)|'"$READ_TIMEOUT"'|')

echo "$SCRIPT" | /usr/bin/env bash -s
