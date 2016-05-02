#!/bin/bash
# Download Required Files
curl -o ./provision-builder.sh https://s3.amazonaws.com/circleci-enterprise/provision-builder.sh
curl -o ./init-builder.sh https://s3.amazonaws.com/circleci-enterprise/init-builder-0.2.sh

# Start Provisioning
sudo bash ./provision-builder.sh

# Create Sparse File
sudo truncate -s 40G /tmp/sparse-file.img

# Initialize the Builders
sudo \
  SERVICES_PRIVATE_IP="192.168.205.10" \
  CIRCLE_BUILD_VOLUMES="/tmp/sparse-file.img" \
  CIRCLE_CONTAINER_MEMORY_LIMIT="1G" \
  CIRCLE_SECRET_PASSPHRASE='d3d662b598d773393f9d81fb6ff5b6cc571e555a' \
  CIRCLE_CONTAINER_CPUS="1" \
  bash ./init-builder.sh

# Start up CircleCI Services
sudo service circle-image start
