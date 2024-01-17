

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
export DEPLOYMENT_ID='test043'
export BRANCH_NAME='main'
export AZURESQL_SERVER_PASSWORD='Sydney@123'
export RESOURCE_GROUP_NAME='mdw-dataops-azuresq-rg0435'
export RESOURCE_GROUP_LOCATION='australiaeast'
export GITHUB_SERVICE_CONNECTION_ID="2159ad85-fe4c-4e52-be05-023bf623f90b"



: '
. ./scripts/common.sh
. ./scripts/init_environment.sh


# Retrieve azure sub information
az_sub=$(az account show --output json)
export AZURE_SUBSCRIPTION_ID=$(echo $az_sub | jq -r '.id')
az_sub_name=$(echo $az_sub | jq -r '.name')
echo 'Azure Subscription ID:' $AZURE_SUBSCRIPTION_ID 
echo 'Azure Subscription Name' $az_sub_name


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


pipeline_name=mdwdo-azsql-${DEPLOYMENT_ID}-azuresql-02-build
echo "Creating Pipeline: $pipeline_name in Azure DevOps"
az pipelines create \
    --name "$pipeline_name" \
    --description 'This pipelines build the DACPAC and publishes it as a Build Artifact' \
    --repository "$GITHUB_REPO_URL" \
    --branch "$BRANCH_NAME" \
    --yaml-path 'single_tech_samples/azuresql/pipelines/azure-pipelines-02-build.yml' \
    --service-connection "$GITHUB_SERVICE_CONNECTION_ID"





echo "Deploying resources into $RESOURCE_GROUP_NAME"
sqlsrvr_name=mdwdo-azsql-${DEPLOYMENT_ID}-sqlsrvr-03
arm_output=$(az group deployment create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --template-file "./infrastructure/azuredeploy.json" \
    --parameters AZURESQL_SERVER_PASSWORD=${AZURESQL_SERVER_PASSWORD} azuresql_srvr_name=${sqlsrvr_name} azuresql_srvr_display_name="SQL Server - Simple Multi-Stage Pipeline" deployment_id=${DEPLOYMENT_ID} \
    --output json)

 '

echo 'after comment --------------------------------------'

# Create pipeline
pipeline_name=mdwdo-azsql-${DEPLOYMENT_ID}-azuresql-03-simple-multi-stage
echo "Creating Pipeline: $pipeline_name in Azure DevOps"
pipeline_id=$(az pipelines create \
    --name "$pipeline_name" \
    --description 'This pipelines is a simple two stage pipeline which builds the DACPAC and deploy to a target AzureSQLDB instance' \
    --repository "$GITHUB_REPO_URL" \
    --branch "$BRANCH_NAME" \
    --yaml-path 'single_tech_samples/azuresql/pipelines/azure-pipelines-03-simple-multi-stage.yml' \
    --service-connection "$GITHUB_SERVICE_CONNECTION_ID" \
    --skip-first-run true \
    --output json | jq -r '.id')


# Create Variables
azuresql_srvr_name=$(echo $arm_output | jq -r '.properties.outputs.azuresql_srvr_name.value')
az pipelines variable create \
    --name AZURESQL_SERVER_NAME \
    --pipeline-id $pipeline_id \
    --value "$azuresql_srvr_name"

azuresql_db_name=$(echo $arm_output | jq -r '.properties.outputs.azuresql_db_name.value')
az pipelines variable create \
    --name AZURESQL_DB_NAME \
    --pipeline-id $pipeline_id \
    --value $azuresql_db_name

azuresql_srvr_admin=$(echo $arm_output | jq -r '.properties.outputs.azuresql_srvr_admin.value')
az pipelines variable create \
    --name AZURESQL_SERVER_USERNAME \
    --pipeline-id $pipeline_id \
    --value $azuresql_srvr_admin

az pipelines variable create \
    --name AZURESQL_SERVER_PASSWORD \
    --pipeline-id $pipeline_id \
    --secret true \
    --value $AZURESQL_SERVER_PASSWORD

az pipelines run --name $pipeline_name