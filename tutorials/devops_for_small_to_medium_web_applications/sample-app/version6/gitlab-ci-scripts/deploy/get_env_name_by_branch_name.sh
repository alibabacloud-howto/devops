#!/usr/bin/env bash
#
# Print the environment name according to the branch name.
#
# Parameters:
#   - $1 = BRANCH_NAME
#

BRANCH_NAME=$1
ENV_NAME_MASTER="dev"
ENV_NAME_PRE_PRODUCTION="pre-prod"
ENV_NAME_PRODUCTION="prod"

if [[ ${BRANCH_NAME} == "production" ]]; then
    echo ${ENV_NAME_PRODUCTION};
elif [[ ${BRANCH_NAME} == "pre-production" ]]; then
    echo ${ENV_NAME_PRE_PRODUCTION};
else
    echo ${ENV_NAME_MASTER};
fi