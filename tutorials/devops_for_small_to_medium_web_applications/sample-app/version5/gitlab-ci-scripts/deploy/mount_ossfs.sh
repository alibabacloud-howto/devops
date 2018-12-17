#!/usr/bin/env bash
#
# Mount an OSS bucket with OSSFS.
#
# Required global variables:
#   - ALICLOUD_ACCESS_KEY
#   - ALICLOUD_SECRET_KEY
#   - GITLAB_BUCKET_NAME
#   - GITLAB_BUCKET_ENDPOINT
#   - BUCKET_LOCAL_PATH
#

echo "Mounting the OSS bucket ${GITLAB_BUCKET_NAME} (endpoint ${GITLAB_BUCKET_ENDPOINT}) into ${BUCKET_LOCAL_PATH}..."

# Configure OSSFS
echo "$GITLAB_BUCKET_NAME:$ALICLOUD_ACCESS_KEY:$ALICLOUD_SECRET_KEY" > /etc/passwd-ossfs
chmod 640 /etc/passwd-ossfs

# Mount our bucket
mkdir -p "$BUCKET_LOCAL_PATH"
ossfs "$GITLAB_BUCKET_NAME" "$BUCKET_LOCAL_PATH" -ourl="$GITLAB_BUCKET_ENDPOINT"

echo "OSS bucket ${GITLAB_BUCKET_NAME} mounted with success into ${BUCKET_LOCAL_PATH}."
