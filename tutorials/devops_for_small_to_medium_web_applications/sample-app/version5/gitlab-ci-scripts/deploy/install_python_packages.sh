#!/usr/bin/env bash
#
# Install PIP and aliyun-log-python-sdk.
#

echo "Installing Python packages..."

export DEBIAN_FRONTEND=noninteractive
apt-get -y update
apt-get -y install python3-pip

pip3 install -U aliyun-log-python-sdk

echo "Python packages installed with success."