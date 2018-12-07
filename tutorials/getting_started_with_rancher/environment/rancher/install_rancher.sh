#!/usr/bin/env bash

# Update the machine
export DEBIAN_FRONTEND=noninteractive
apt-get -y update
apt-get -y upgrade

# Add a new repository for apt-get for Docker
apt-get -y install software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
apt-get -y update

# Install Docker
apt-get -y install apt-transport-https ca-certificates software-properties-common docker-ce

# Install and run Rancher
docker run -d --restart=unless-stopped -p 80:80 -p 443:443 rancher/rancher:latest
