

set -o errexit
set -o pipefail
# set -o xtrace # For debugging

# REQUIRED VARIABLES:
# GITHUB_REPO_URL - Github URL
# GITHUB_PAT_TOKEN - Github PAT Token

# OPTIONAL VARIABLES
# DEPLOYMENT_ID - Identifier to append to names of resource created for this deployment. Resources will also be tagged with this. Defaults to generated string.
# BRANCH_NAME - Branch that pipelines will be deployed for. Defaults to main.
# AZURESQL_SERVER_PASSWORD - Password for the sqlAdmin account. Defaults to generated value.
# RESOURCE_GROUP_NAME - resource group name
# RESOURCE_GROUP_LOCATION - resource group location (ei. australiaeast)

export GITHUB_REPO_URL="https://github.com/gaganrkapoor/modern-data-warehouse-dataops"
export GITHUB_PAT_TOKEN="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"
export DEPLOYMENT_ID='0435205055'
export BRANCH_NAME='master'
export AZURESQL_SERVER_PASSWORD='Sydney123'
export RESOURCE_GROUP_NAME='rg0435'
export RESOURCE_GROUP_LOCATION='australiaeast'


. ./scripts/common.sh
. ./scripts/init_environment.sh


# Retrieve azure sub information
az_sub=$(az account show --output json)
export AZURE_SUBSCRIPTION_ID=$(echo $az_sub | jq -r '.id')
az_sub_name=$(echo $az_sub | jq -r '.name')
echo 'Azure Subscription ID:' $AZURE_SUBSCRIPTION_ID 
echo 'Azure Subscription Name' $az_sub_name

: '
# Create Service Account
az_sp=$(az ad sp create-for-rbac \
    --role contributor \
    --scopes /subscriptions/ $AZURE_SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME \
    --name 'mdwdo-azsql_gk123' \
    --output json)
export SERVICE_PRINCIPAL_ID=$(echo $az_sp | jq -r '.appId')
az_sp_tenant_id=$(echo $az_sp | jq -r '.tenant')
echo $SERVICE_PRINCIPAL_ID
echo $az_sp_tenant_id
 '

echo 'after comment --------------------------------------'




export AZURE_DEVOPS_EXT_GITHUB_PAT=$GITHUB_PAT_TOKEN
echo "Creating Github service connection in Azure DevOps"
export GITHUB_SERVICE_CONNECTION_ID=$(az devops service-endpoint github create \
    --name "mdwdo-azsql-github" \
    --github-url "$GITHUB_REPO_URL" \
    --output json | jq -r '.id')
echo $GITHUB_SERVICE_CONNECTION_ID


pipeline_name=mdwdo-azsql-${DEPLOYMENT_ID}-azuresql-01-validate-pr
echo "Creating Pipeline: $pipeline_name in Azure DevOps"
az pipelines create \
    --name "$pipeline_name" \
    --description 'This pipelines validates pull requests to BRANCH_NAME' \
    --repository "$GITHUB_REPO_URL" \
    --branch "$BRANCH_NAME" \
    --yaml-path 'single_tech_samples/azuresql/pipelines/azure-pipelines-01-validate-pr.yml' \
    --service-connection "$GITHUB_SERVICE_CONNECTION_ID"
