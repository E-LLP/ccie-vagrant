#!/bin/bash

set -ex

if [[ $(id -u) -ne 0 ]] ; then echo "Please run as root" ; exit 1 ; fi

function install_ubuntu() {
    # Replicated helper stuff
    #apt-key adv --keyserver hkp://pgp.mit.edu:80 --recv-keys B6B4FAC534D32FF0
    curl -o /tmp/34D32FF0.asc https://circleci-enterprise.s3.amazonaws.com/34D32FF0.asc
    apt-key add /tmp/34D32FF0.asc
    echo "deb http://circleci-enterprise.s3.amazonaws.com/debs stable main" > /etc/apt/sources.list.d/circle.list

    curl -sSL https://get.replicated.com | sudo sh

    apt-get install -y circle-replicated
    echo manual > /etc/init/circleci-splash.override
}

function install_non_ubuntu() {
    curl -sSL https://get.replicated.com | sudo sh
}

if (grep -q ID=ubuntu /etc/os-release ) && (grep -q 14.04 /etc/os-release)
then
    install_ubuntu
else
    install_non_ubuntu
fi

set +x

PRIVATE_IP="192.168.205.10"

echo
echo "####################################################################################"
echo "## Services box is getting ready.  Please follow the installation"
echo "## wizard at the System Console at port 8800 (e.g. http://${PRIVATE_IP}:8800/ )"
echo "##"
echo "## When starting builder, use ${PRIVATE_IP} as the SERVICES_PRIVATE_IP variable"
echo "####################################################################################"
