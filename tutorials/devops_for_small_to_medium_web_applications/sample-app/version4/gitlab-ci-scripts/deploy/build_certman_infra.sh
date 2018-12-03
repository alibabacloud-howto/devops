#!/usr/bin/env bash
#
# Build the certificate manager infrastructure (RDS, VM image, ECS, ...)
#
# Required global variables:
#   - ALICLOUD_ACCESS_KEY
#   - ALICLOUD_SECRET_KEY
#   - ALICLOUD_REGION
#   - ENV_NAME
#   - DOMAIN_NAME
#   - SUB_DOMAIN_NAME
#   - EMAIL_ADDRESS
#   - ECS_ROOT_PASSWORD
#   - GITLAB_BUCKET_NAME
#   - GITLAB_BUCKET_ENDPOINT
#   - BUCKET_LOCAL_PATH
#   - CI_PIPELINE_IID
#   - OSSFS_VERSION
#

echo "Building the certificate manager infrastructure (environment: ${ENV_NAME}, region: ${ALICLOUD_REGION})..."

# Set values for Terraform and Packer variables
export TF_VAR_env=${ENV_NAME}
export TF_VAR_db_account_password=${DB_ACCOUNT_PASSWORD}
export TF_VAR_ecs_root_password=${ECS_ROOT_PASSWORD}

export IMAGE_VERSION=${CI_PIPELINE_IID}
export ENVIRONMENT=${ENV_NAME}
export BUCKET_NAME=${GITLAB_BUCKET_NAME}
export BUCKET_ENDPOINT=${GITLAB_BUCKET_ENDPOINT}

# Extract Alibaba Cloud information for building the application image
cd infrastructure/15_certman/05_image
export BUCKET_DIR_PATH="$BUCKET_LOCAL_PATH/infrastructure/$ENV_NAME/15_certman/05_image"
mkdir -p ${BUCKET_DIR_PATH}
cp ${BUCKET_DIR_PATH}/*.tfstate* .
terraform init -input=false
terraform apply -input=false -auto-approve
rm -f ${BUCKET_DIR_PATH}/*
cp *.tfstate* ${BUCKET_DIR_PATH}
export SOURCE_IMAGE=$(terraform output image_id)
export INSTANCE_TYPE=$(terraform output instance_type)

# Build the certificate manager image
packer build certman_image.json

# Create/update the ECS, SLB server group and forward rule
cd ../10_ecs_slb_rule
export BUCKET_DIR_PATH="$BUCKET_LOCAL_PATH/infrastructure/$ENV_NAME/15_certman/10_ecs_slb_rule"
mkdir -p ${BUCKET_DIR_PATH}
cp ${BUCKET_DIR_PATH}/*.tfstate* .
terraform init -input=false
terraform apply -input=false -auto-approve
rm -f ${BUCKET_DIR_PATH}/*
cp *.tfstate* ${BUCKET_DIR_PATH}

cd ../../..

echo "Certificate manager infrastructure successfully built (environment: ${ENV_NAME}, region: ${ALICLOUD_REGION})."