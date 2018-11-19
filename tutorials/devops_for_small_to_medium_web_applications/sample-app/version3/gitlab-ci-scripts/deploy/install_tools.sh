#!/usr/bin/env bash
#
# Install OSSFS, Terraform and Packer.
#
# Required global variables:
#   - OSSFS_VERSION
#   - TERRAFORM_VERSION
#   - PACKER_VERSION
#

echo "Installing OSSFS version ${OSSFS_VERSION}, Terraform version ${TERRAFORM_VERSION} and Packer version ${PACKER_VERSION}..."

# Create a temporary folder
mkdir -p installation_tmp
cd installation_tmp

# Install OSSFS
apt-get -y update
apt-get -y install gdebi-core wget unzip
wget "https://github.com/aliyun/ossfs/releases/download/v${OSSFS_VERSION}/ossfs_${OSSFS_VERSION}_ubuntu16.04_amd64.deb"
gdebi -n "ossfs_${OSSFS_VERSION}_ubuntu16.04_amd64.deb"

# Install Terraform
wget "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
unzip "terraform_${TERRAFORM_VERSION}_linux_amd64.zip" -d /usr/local/bin/

# Install Packer
wget "https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip"
unzip "packer_${PACKER_VERSION}_linux_amd64.zip" -d /usr/local/bin/

# Display the version of installed tools
echo "Installed Terraform version:"
terraform version
echo "Installed Packer version:"
packer version

# Delete the temporary folder
cd ..
rm -rf installation_tmp

echo "Installation of OSSFS, Terraform and Packer completed."
