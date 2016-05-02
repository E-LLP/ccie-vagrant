#!/bin/sh

set -ex

curl -o /tmp/34D32FF0.asc https://circleci-enterprise.s3.amazonaws.com/34D32FF0.asc
apt-key add /tmp/34D32FF0.asc
echo "deb http://circleci-enterprise.s3.amazonaws.com/debs stable main" > /etc/apt/sources.list.d/circle.list

curl -o ./install.sh https://get.replicated.com
sudo bash ./install.sh local_address="192.168.205.10"

apt-get install -y circle-replicated
echo manual > /etc/init/circleci-splash.override

set +x

PRIVATE_IP="192.168.205.10"

echo
echo "####################################################################################"
echo "## Services box is getting ready.  Please follow the installation"
echo "## wizard at the System Console at port 8800 (e.g. http://${PRIVATE_IP}:8800/ )"
echo "##"
echo "## When starting builder, use ${PRIVATE_IP} as the SERVICES_PRIVATE_IP variable"
echo "####################################################################################"
