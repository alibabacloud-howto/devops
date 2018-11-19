#!/usr/bin/env bash
#
# Print the sub-domain name according to the branch name.
#
# Parameters:
#   - $1 = BRANCH_NAME
#

BRANCH_NAME=$1
SUB_DOMAIN_NAME_MASTER="dev"
SUB_DOMAIN_NAME_PRE_PRODUCTION="pre-prod"
SUB_DOMAIN_NAME_PRODUCTION="www"

if [[ ${BRANCH_NAME} == "production" ]]; then
    echo ${SUB_DOMAIN_NAME_PRODUCTION};
elif [[ ${BRANCH_NAME} == "pre-production" ]]; then
    echo ${SUB_DOMAIN_NAME_PRE_PRODUCTION};
else
    echo ${SUB_DOMAIN_NAME_MASTER};
fi