#!/bin/bash

# Access granted under MIT Open Source License: https://en.wikipedia.org/wiki/MIT_License
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated 
# documentation files (the "Software"), to deal in the Software without restriction, including without limitation 
# the rights to use, copy, modify, merge, publish, distribute, sublicense, # and/or sell copies of the Software, 
# and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions 
# of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED 
# TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL 
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF 
# CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
# DEALINGS IN THE SOFTWARE.

#######################################################
# Deploys all necessary azure resources and stores
# configuration information in an .ENV file
#
# Prerequisites:
# - User is logged in to the azure cli
# - Correct Azure subscription is selected
#######################################################

set -o errexit
set -o pipefail
set -o nounset
set -o xtrace # For debugging

#az login --tenant "9e375c99-a8c8-49a8-8127-1ea23e715cad"
export PROJECT='mdwdops'
export DEPLOYMENT_ID='7123'
export ENV_NAME='dev'
export AZURE_LOCATION='australiaeast'
export AZURE_SUBSCRIPTION_ID='d3c00b3e-62a3-4d55-bed2-a0c29891af20'
export AZURESQL_SERVER_PASSWORD='Allity@123'
export MSYS_NO_PATHCONV=1

echo "--------------------STEP 1: Deploying all azure resources to subscription for Deployment ID: ------------------- $DEPLOYMENT_ID"  
echo '--------------------STEP 1: Deploying all azure resources to subscription for Deployment ID: -------------------' $DEPLOYMENT_ID  >> variablevalues.log
echo '**** --- PROJECT :  '$PROJECT >> variablevalues.log
echo '**** --- DEPLOYMENT_ID :  '$DEPLOYMENT_ID >> variablevalues.log
echo '**** --- ENV_NAME :  '$ENV_NAME >> variablevalues.log
echo '**** --- AZURE_LOCATION :  '$AZURE_LOCATION >> variablevalues.log
echo '**** --- AZURE_SUBSCRIPTION_ID :  '$AZURE_SUBSCRIPTION_ID >> variablevalues.log
echo '**** --- AZURESQL_SERVER_PASSWORD :  '$AZURESQL_SERVER_PASSWORD >> variablevalues.log


# Set account to where ARM template will be deployed to
echo "Deploying to Subscription: $AZURE_SUBSCRIPTION_ID"
az account set --subscription "$AZURE_SUBSCRIPTION_ID"

# Create resource group
resource_group_name="$PROJECT-$DEPLOYMENT_ID-$ENV_NAME-rg"
echo "Creating resource group: $resource_group_name"
az group create --name "$resource_group_name" --location "$AZURE_LOCATION" --tags Environment="$ENV_NAME"

# By default, set all KeyVault permission to deployer
# Retrieve KeyVault User Id
echo '**** --- resource_group_name :  '$resource_group_name >> variablevalues.log
kv_owner_object_id=$(az ad signed-in-user show --output json | jq -r '.id')

echo '**** --- kv_owner_object_id :  '$kv_owner_object_id >> variablevalues.log

# Validate arm template
echo "Validating deployment"
arm_output=$(az deployment group validate \
    --resource-group "$resource_group_name" \
    --template-file "./infrastructure/main.bicep" \
    --parameters @"./infrastructure/main.parameters.${ENV_NAME}.json" \
    --parameters project="${PROJECT}" keyvault_owner_object_id="${kv_owner_object_id}" deployment_id="${DEPLOYMENT_ID}" sql_server_password="${AZURESQL_SERVER_PASSWORD}" \
    --output json)

# Deploy arm template
echo "Deploying resources into $resource_group_name"
arm_output=$(az deployment group create \
    --resource-group "$resource_group_name" \
    --template-file "./infrastructure/main.bicep" \
    --parameters @"./infrastructure/main.parameters.${ENV_NAME}.json" \
    --parameters project="${PROJECT}" deployment_id="${DEPLOYMENT_ID}" keyvault_owner_object_id="${kv_owner_object_id}" sql_server_password="${AZURESQL_SERVER_PASSWORD}" \
    --output json)

if [[ -z $arm_output ]]; then
    echo >&2 "ARM deployment failed."
    exit 1
fi
echo "$arm_output" > armfile.log

########################
# RETRIEVE KEYVAULT INFORMATION

echo "Retrieving KeyVault information from the deployment."

kv_name=$(echo "$arm_output" | jq -r '.properties.outputs.keyvault_name.value')
kv_dns_name=https://${kv_name}.vault.azure.net/

echo "key vault name is : $kv_name"

echo '**** --- kv_name :  '$kv_name >> variablevalues.log
echo '**** --- kv_dns_name :  '$kv_dns_name >> variablevalues.log
# Store in KeyVault
az keyvault secret set --vault-name "$kv_name" --name "kvUrl" --value "$kv_dns_name"
az keyvault secret set --vault-name "$kv_name" --name "subscriptionId" --value "$AZURE_SUBSCRIPTION_ID"


#########################
# CREATE AND CONFIGURE SERVICE PRINCIPAL FOR ADLA GEN2

# Retrive account and key
azure_storage_account=$(echo "$arm_output" | jq -r '.properties.outputs.storage_account_name.value')
azure_storage_key=$(az storage account keys list \
    --account-name "$azure_storage_account" \
    --resource-group "$resource_group_name" \
    --output json |
    jq -r '.[0].value')
echo '**** --- azure_storage_account :  '$azure_storage_account >> variablevalues.log
echo '**** --- azure_storage_key :  '$azure_storage_key >> variablevalues.log

# Add file system storage account
storage_file_system=datalake
echo "Creating ADLS Gen2 File system: $storage_file_system"
az storage container create --name $storage_file_system --account-name "$azure_storage_account" --account-key "$azure_storage_key"

echo '**** --- storage_file_system :  '$storage_file_system >> variablevalues.log
echo "Creating folders within the file system."
# Create folders for databricks libs
az storage fs directory create -n '/sys/databricks/libs' -f $storage_file_system --account-name "$azure_storage_account" --account-key "$azure_storage_key"
# Create folders for SQL external tables
az storage fs directory create -n '/data/dw/fact_parking' -f $storage_file_system --account-name "$azure_storage_account" --account-key "$azure_storage_key"
az storage fs directory create -n '/data/dw/dim_st_marker' -f $storage_file_system --account-name "$azure_storage_account" --account-key "$azure_storage_key"
az storage fs directory create -n '/data/dw/dim_parking_bay' -f $storage_file_system --account-name "$azure_storage_account" --account-key "$azure_storage_key"
az storage fs directory create -n '/data/dw/dim_location' -f $storage_file_system --account-name "$azure_storage_account" --account-key "$azure_storage_key"

echo "Uploading seed data to data/seed"
az storage blob upload --container-name $storage_file_system --account-name "$azure_storage_account" --account-key "$azure_storage_key" \
    --file data/seed/dim_date.csv --name "data/seed/dim_date/dim_date.csv" --overwrite
az storage blob upload --container-name $storage_file_system --account-name "$azure_storage_account" --account-key "$azure_storage_key" \
    --file data/seed/dim_time.csv --name "data/seed/dim_time/dim_time.csv" --overwrite

# Set Keyvault secrets
az keyvault secret set --vault-name "$kv_name" --name "datalakeAccountName" --value "$azure_storage_account"
az keyvault secret set --vault-name "$kv_name" --name "datalakeKey" --value "$azure_storage_key"
az keyvault secret set --vault-name "$kv_name" --name "datalakeurl" --value "https://$azure_storage_account.dfs.core.windows.net"

echo '**** --- datalakeAccountName :  '$azure_storage_account >> variablevalues.log
echo '**** --- datalakeKey :  '$azure_storage_key >> variablevalues.log
echo '**** --- datalakeurl :  '"https://$azure_storage_account.dfs.core.windows.net" >> variablevalues.log

####################
# APPLICATION INSIGHTS

echo "Retrieving ApplicationInsights information from the deployment."
appinsights_name=$(echo "$arm_output" | jq -r '.properties.outputs.appinsights_name.value')
appinsights_key=$(az monitor app-insights component show \
    --app "$appinsights_name" \
    --resource-group "$resource_group_name" \
    --output json |
    jq -r '.instrumentationKey')
appinsights_connstr=$(az monitor app-insights component show \
    --app "$appinsights_name" \
    --resource-group "$resource_group_name" \
    --output json |
    jq -r '.connectionString')

# Store in Keyvault
az keyvault secret set --vault-name "$kv_name" --name "applicationInsightsKey" --value "$appinsights_key"
az keyvault secret set --vault-name "$kv_name" --name "applicationInsightsConnectionString" --value "$appinsights_connstr"

# # RETRIEVE DATABRICKS INFORMATION AND CONFIGURE WORKSPACE

# Note: SP is required because Credential Passthrough does not support ADF (MSI) as of July 2021
echo "Creating Service Principal (SP) for access to ADLA Gen2 used in Databricks mounting"
stor_id=$(az storage account show \
    --name "$azure_storage_account" \
    --resource-group "$resource_group_name" \
    --output json |
    jq -r '.id')
sp_stor_name="${PROJECT}-stor-${ENV_NAME}-${DEPLOYMENT_ID}-sp"
sp_stor_out=$(az ad sp create-for-rbac \
    --role "Storage Blob Data Contributor" \
    --scopes "$stor_id" \
    --name "$sp_stor_name" \
    --output json)

# store storage service principal details in Keyvault
sp_stor_id=$(echo "$sp_stor_out" | jq -r '.appId')
sp_stor_pass=$(echo "$sp_stor_out" | jq -r '.password')
sp_stor_tenant=$(echo "$sp_stor_out" | jq -r '.tenant')
az keyvault secret set --vault-name "$kv_name" --name "spStorName" --value "$sp_stor_name"
az keyvault secret set --vault-name "$kv_name" --name "spStorId" --value "$sp_stor_id"
az keyvault secret set --vault-name "$kv_name" --name "spStorPass" --value "$sp_stor_pass"
az keyvault secret set --vault-name "$kv_name" --name "spStorTenantId" --value "$sp_stor_tenant"

echo '**** --- spStorName :  '$sp_stor_name >> variablevalues.log
echo '**** --- spStorId :  '$sp_stor_id >> variablevalues.log
echo '**** --- spStorPass :  '$sp_stor_pass >> variablevalues.log
echo '**** --- sp_stor_tenant :  '$sp_stor_tenant >> variablevalues.log

echo "Generate Databricks token"
databricks_host=https://$(echo "$arm_output" | jq -r '.properties.outputs.databricks_output.value.properties.workspaceUrl')
databricks_workspace_resource_id=$(echo "$arm_output" | jq -r '.properties.outputs.databricks_id.value')
databricks_aad_token=$(az account get-access-token --resource 2ff814a6-3304-4ab8-85cb-cd0e6f879c1d --output json | jq -r .accessToken) # Databricks app global id

echo '**** --- databricks_host :  '$databricks_host >> variablevalues.log
echo '**** --- databricks_workspace_resource_id :  '$databricks_workspace_resource_id >> variablevalues.log
echo '**** --- databricks_aad_token :  '$databricks_aad_token >> variablevalues.log

echo "Configuring databircks cli with aad token"
export DATABRICKS_AAD_TOKEN=$databricks_aad_token
export DATABRICKS_HOST=$databricks_host
databricks configure --jobs-api-version 2.1 --host $databricks_host --aad-token

# Use AAD token configured in databricks config file to generate PAT token in databricks environment
#databricks_token_json=$(databricks tokens create --comment 'deployment123')
#databricks_token=$(echo "$databricks_token_json" | jq -r '.token_value')
#echo '**** --- databricks_token :  '$databricks_token >> variablevalues.log

# Save in KeyVault
az keyvault secret set --vault-name "$kv_name" --name "databricksDomain" --value "$databricks_host"
#az keyvault secret set --vault-name "$kv_name" --name "databricksToken" --value "$databricks_token"
az keyvault secret set --vault-name "$kv_name" --name "databricksWorkspaceResourceId" --value "$databricks_workspace_resource_id"

# Configure databricks (KeyVault-backed Secret scope, mount to storage via SP, databricks tables, cluster)
# NOTE: must use AAD token, not PAT token

DATABRICKS_AAD_TOKEN=$databricks_aad_token \
DATABRICKS_HOST=$databricks_host \
KEYVAULT_DNS_NAME=$kv_dns_name \
KEYVAULT_RESOURCE_ID=$(echo "$arm_output" | jq -r '.properties.outputs.keyvault_resource_id.value') \
    bash -c "./scripts/configure_databricks.sh"
 
echo "STEP 1: Deploying all azure resources to subscription Completed Successfully"