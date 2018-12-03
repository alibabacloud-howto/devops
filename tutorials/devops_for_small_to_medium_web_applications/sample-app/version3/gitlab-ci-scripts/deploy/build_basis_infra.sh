#!/usr/bin/env bash
#
# Build the basis infrastructure (VPC, VSwitches, ...)
#
# Required global variables:
#   - ALICLOUD_ACCESS_KEY
#   - ALICLOUD_SECRET_KEY
#   - ALICLOUD_REGION
#   - ENV_NAME
#   - DOMAIN_NAME
#   - SUB_DOMAIN_NAME
#   - BUCKET_LOCAL_PATH
#

echo "Building the basis infrastructure (environment: ${ENV_NAME},\
 region: ${ALICLOUD_REGION},\
 domain: ${DOMAIN_NAME},\
 sub-domain: ${SUB_DOMAIN_NAME})..."

# Set values for Terraform variables
export TF_VAR_env=${ENV_NAME}
export TF_VAR_domain_name=${DOMAIN_NAME}
export TF_VAR_sub_domain_name=${SUB_DOMAIN_NAME}

# Run the Terraform scripts in 05_vpc_slb_eip_domain
cd infrastructure/05_vpc_slb_eip_domain
export BUCKET_DIR_PATH="$BUCKET_LOCAL_PATH/infrastructure/$ENV_NAME/05_vpc_slb_eip_domain"
mkdir -p ${BUCKET_DIR_PATH}
cp ${BUCKET_DIR_PATH}/*.tfstate* .
terraform init -input=false
terraform apply -input=false -auto-approve
terraform apply -input=false -auto-approve
# Note: the last line has to be executed twice because of a bug in the alicloud_dns_record resource
rm -f ${BUCKET_DIR_PATH}/*
cp *.tfstate* ${BUCKET_DIR_PATH}

# Run the Terraform scripts in 06_domain_step_2
cd ../06_domain_step_2
export BUCKET_DIR_PATH="$BUCKET_LOCAL_PATH/infrastructure/$ENV_NAME/06_domain_step_2"
mkdir -p ${BUCKET_DIR_PATH}
cp ${BUCKET_DIR_PATH}/*.tfstate* .
terraform init -input=false
terraform apply -input=false -auto-approve
rm -f ${BUCKET_DIR_PATH}/*
cp *.tfstate* ${BUCKET_DIR_PATH}

cd ../..

echo "Basis infrastructure successfully built (environment: ${ENV_NAME}, region: ${ALICLOUD_REGION})."
