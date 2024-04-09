#!/bin/bash

. ./scripts/common.sh


###############
# Deploy Pipelines: validate pr

pipeline_name=mdwdo-azsql-${DEPLOYMENT_ID}-azuresql-01-validate-pr
echo "Creating Pipeline: $pipeline_name in Azure DevOps"
echo "From Validate PR.sh -> GITHUB Service Connection ID is : " $GITHUB_SERVICE_CONNECTION_ID
echo "From Validate PR.sh -> GITHUB REPO URL is : " $GITHUB_REPO_URL
echo "From Validate PR.sh -> Branchname is : " $BRANCH_NAME

az pipelines create \
    --name "$pipeline_name" \
    --description 'This pipelines validates pull requests to BRANCH_NAME' \
    --repository "$GITHUB_REPO_URL" \
    --branch "$BRANCH_NAME" \
    --yaml-path 'single_tech_samples/azuresql/pipelines/azure-pipelines-01-validate-pr.yml' \
    --service-connection "$GITHUB_SERVICE_CONNECTION_ID"
