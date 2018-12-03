#!/usr/bin/env bash
#
# Build the web application infrastructure (RDS, VM image, ECS, ...)
#
# Required global variables:
#   - ALICLOUD_ACCESS_KEY
#   - ALICLOUD_SECRET_KEY
#   - ALICLOUD_REGION
#   - ENV_NAME
#   - DB_ACCOUNT_PASSWORD
#   - ECS_ROOT_PASSWORD
#   - BUCKET_LOCAL_PATH
#   - CI_PIPELINE_IID
#

echo "Building the application infrastructure (environment: ${ENV_NAME}, region: ${ALICLOUD_REGION})..."

# Set values for Terraform and Packer variables
export TF_VAR_env=${ENV_NAME}
export TF_VAR_db_account_password=${DB_ACCOUNT_PASSWORD}
export TF_VAR_ecs_root_password=${ECS_ROOT_PASSWORD}

export APPLICATION_PATH=$(pwd)/$(ls target/*.jar)
export PROPERTIES_PATH=$(pwd)/src/main/resources/application.properties
export IMAGE_VERSION=${CI_PIPELINE_IID}
export ENVIRONMENT=${ENV_NAME}
export RDS_DATABASE=todolist
export RDS_ACCOUNT=todolist
export RDS_PASSWORD=${DB_ACCOUNT_PASSWORD}

# Create/update the application database
cd infrastructure/10_webapp/05_rds
export BUCKET_DIR_PATH="$BUCKET_LOCAL_PATH/infrastructure/$ENV_NAME/10_webapp/05_rds"
mkdir -p ${BUCKET_DIR_PATH}
cp ${BUCKET_DIR_PATH}/*.tfstate* .
terraform init -input=false
terraform apply -input=false -auto-approve
rm -f ${BUCKET_DIR_PATH}/*
cp *.tfstate* ${BUCKET_DIR_PATH}
export RDS_CONNECTION_STRING=$(terraform output app_rds_connection_string)

# Extract Alibaba Cloud information for building the application image
cd ../10_image
export BUCKET_DIR_PATH="$BUCKET_LOCAL_PATH/infrastructure/$ENV_NAME/10_webapp/10_image"
mkdir -p ${BUCKET_DIR_PATH}
cp ${BUCKET_DIR_PATH}/*.tfstate* .
terraform init -input=false
terraform apply -input=false -auto-approve
rm -f ${BUCKET_DIR_PATH}/*
cp *.tfstate* ${BUCKET_DIR_PATH}
export SOURCE_IMAGE=$(terraform output image_id)
export INSTANCE_TYPE=$(terraform output instance_type)

# Build the application image
packer build app_image.json

# Create/update the ECS instances
cd ../15_ecs
export BUCKET_DIR_PATH="$BUCKET_LOCAL_PATH/infrastructure/$ENV_NAME/10_webapp/15_ecs"
mkdir -p ${BUCKET_DIR_PATH}
cp ${BUCKET_DIR_PATH}/*.tfstate* .
terraform init -input=false
terraform apply -input=false -auto-approve -parallelism=1
rm -f ${BUCKET_DIR_PATH}/*
cp *.tfstate* ${BUCKET_DIR_PATH}

cd ../../..

echo "Application infrastructure successfully built (environment: ${ENV_NAME}, region: ${ALICLOUD_REGION})."
