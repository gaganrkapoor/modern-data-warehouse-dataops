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

###################
# REQUIRED ENV VARIABLES:
#
# PROJECT
# DEPLOYMENT_ID
# ENV_NAME
# AZURE_LOCATION
# AZURE_SUBSCRIPTION_ID
# AZURESQL_SERVER_PASSWORD


#####################
# DEPLOY ARM TEMPLATE


#az login --tenant "9e375c99-a8c8-49a8-8127-1ea23e715cad"
export PROJECT='mdwdops'
export DEPLOYMENT_ID='7862'
export ENV_NAME='dev'
export AZURE_LOCATION='australiaeast'
export AZURE_SUBSCRIPTION_ID='d3c00b3e-62a3-4d55-bed2-a0c29891af20'
export AZURESQL_SERVER_PASSWORD='Allity@123'
export MSYS_NO_PATHCONV=1

# Set account to where ARM template will be deployed to
echo "Deploying to Subscription: $AZURE_SUBSCRIPTION_ID"
az account set --subscription "$AZURE_SUBSCRIPTION_ID"

# Create resource group
resource_group_name="$PROJECT-$DEPLOYMENT_ID-$ENV_NAME-rg"
echo "Creating resource group: $resource_group_name"
az group create --name "$resource_group_name" --location "$AZURE_LOCATION" --tags Environment="$ENV_NAME"

# By default, set all KeyVault permission to deployer
# Retrieve KeyVault User Id
kv_owner_object_id=$(az ad signed-in-user show --output json | jq -r '.id')

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

# Add file system storage account
storage_file_system=datalake
echo "Creating ADLS Gen2 File system: $storage_file_system"
az storage container create --name $storage_file_system --account-name "$azure_storage_account" --account-key "$azure_storage_key"

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

echo "Generate Databricks token"
databricks_host=https://$(echo "$arm_output" | jq -r '.properties.outputs.databricks_output.value.properties.workspaceUrl')
databricks_workspace_resource_id=$(echo "$arm_output" | jq -r '.properties.outputs.databricks_id.value')
databricks_aad_token=$(az account get-access-token --resource 2ff814a6-3304-4ab8-85cb-cd0e6f879c1d --output json | jq -r .accessToken) # Databricks app global id

# Use AAD token to generate PAT token
databricks_token=$(DATABRICKS_TOKEN=$databricks_aad_token \
    DATABRICKS_HOST=$databricks_host \
    bash -c "databricks tokens create --comment 'deployment'" | jq -r .token_value)

# Save in KeyVault
az keyvault secret set --vault-name "$kv_name" --name "databricksDomain" --value "$databricks_host"
az keyvault secret set --vault-name "$kv_name" --name "databricksToken" --value "$databricks_token"
az keyvault secret set --vault-name "$kv_name" --name "databricksWorkspaceResourceId" --value "$databricks_workspace_resource_id"

# Configure databricks (KeyVault-backed Secret scope, mount to storage via SP, databricks tables, cluster)
# NOTE: must use AAD token, not PAT token
DATABRICKS_TOKEN=$databricks_aad_token \
DATABRICKS_HOST=$databricks_host \
KEYVAULT_DNS_NAME=$kv_dns_name \
KEYVAULT_RESOURCE_ID=$(echo "$arm_output" | jq -r '.properties.outputs.keyvault_resource_id.value') \
    bash -c "./scripts/configure_databricks.sh"

echo "Completed deploying Azure resources $resource_group_name ($ENV_NAME)"


# Configure databricks (KeyVault-backed Secret scope, mount to storage via SP, databricks tables, cluster)
# NOTE: must use AAD token, not PAT token
DATABRICKS_TOKEN="eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsIng1dCI6ImtXYmthYTZxczh3c1RuQndpaU5ZT2hIYm5BdyIsImtpZCI6ImtXYmthYTZxczh3c1RuQndpaU5ZT2hIYm5BdyJ9.eyJhdWQiOiIyZmY4MTRhNi0zMzA0LTRhYjgtODVjYi1jZDBlNmY4NzljMWQiLCJpc3MiOiJodHRwczovL3N0cy53aW5kb3dzLm5ldC85ZTM3NWM5OS1hOGM4LTQ5YTgtODEyNy0xZWEyM2U3MTVjYWQvIiwiaWF0IjoxNzA3MjE1MDY0LCJuYmYiOjE3MDcyMTUwNjQsImV4cCI6MTcwNzIyMDU4NiwiYWNyIjoiMSIsImFpbyI6IkFZUUFlLzhWQUFBQXlueC9memFIKzJYUk9UTlIweHN5ajNmNitqKzZPVU5oSTdrSTMvbitONmI2RkJIMTRjSFdLTkpJVzFtLzJWRGUyUElQQjFaNDU1b2NxWE84SloybWljbEhFcndHcExXODVMaUo0QVk2Skg3bFRJZ2s3TCtjaVVKaFZ0R0lzeXZmNUZmRTJ3NnFJeDF3WjJzYVZUd25yNmxMM2Q3d25pV1F5K2dKeWlNVHRpaz0iLCJhbHRzZWNpZCI6IjE6bGl2ZS5jb206MDAwNjdGRkU5QUUwMDcyRSIsImFtciI6WyJwd2QiLCJtZmEiXSwiYXBwaWQiOiIwNGIwNzc5NS04ZGRiLTQ2MWEtYmJlZS0wMmY5ZTFiZjdiNDYiLCJhcHBpZGFjciI6IjAiLCJlbWFpbCI6ImdhZ2FucmthcG9vckBob3RtYWlsLmNvbSIsImZhbWlseV9uYW1lIjoiS2Fwb29yIiwiZ2l2ZW5fbmFtZSI6IkdhZ2FuIiwiaWRwIjoibGl2ZS5jb20iLCJpcGFkZHIiOiIyMDMuMjE5LjE5Ni4xNDYiLCJuYW1lIjoiR2FnYW4gS2Fwb29yIEhvdG1haWwiLCJvaWQiOiJiZDNlN2ZkYi01NGU0LTRmMzMtOWRmYy04MDMwOGQyODgwMDUiLCJwdWlkIjoiMTAwMzIwMDIxMDM4RTlEMiIsInJoIjoiMC5BV1lBbVZ3M25zaW9xRW1CSng2aVBuRmNyYVlVLUM4RU03aEtoY3ZORG0tSG5CMW1BSUkuIiwic2NwIjoidXNlcl9pbXBlcnNvbmF0aW9uIiwic3ViIjoiQ2xjdGJINHZVbkpYRzRXRlZENlgyZWpJR21UQklzaC1mbWlMZlhmVzBZQSIsInRpZCI6IjllMzc1Yzk5LWE4YzgtNDlhOC04MTI3LTFlYTIzZTcxNWNhZCIsInVuaXF1ZV9uYW1lIjoibGl2ZS5jb20jZ2FnYW5ya2Fwb29yQGhvdG1haWwuY29tIiwidXRpIjoiZXhwaDFTa0NJVS00b2FhYXAxbEtBQSIsInZlciI6IjEuMCJ9.qnipCx23X3if3f-WS8tz3DuHxmbR1rc4niD6GKVxHT6JDPz_Ly6AIAsDl9nW_sovzfojrQHYQOuACeXrkRghlHTtknUwmjLnAb2TrtiZ53j-xH6Hzr0GBh2h9OxCb86GZroIXv5qSoBSim0yYvcNht2oxPMmcuwMaSccyICmAlbWPtmgegiCqF6xSCTbad2zQYxQWghlLTWPBjAdW6chIt0sfL8sPKnHBQ8QD8OJBhXFQQERfYgEvMxYDYT5SruxMFaTitudAGzJmK9Tm4D6YWBjppjJ-BaxPxFqkIu0lDXAgZNlfwmYG8oNJ84P75AR-0SA4mZj_2NXly74FzOJhg" \
DATABRICKS_HOST="https://adb-2080787828860202.2.azuredatabricks.net/" \
KEYVAULT_DNS_NAME="https://mdwdops-kv-dev-7862.vault.azure.net/" \
KEYVAULT_RESOURCE_ID="/subscriptions/d3c00b3e-62a3-4d55-bed2-a0c29891af20/resourceGroups/mdwdops-7862-dev-rg/providers/Microsoft.KeyVault/vaults/mdwdops-kv-dev-7862" \
    bash -c "./scripts/configure_databricks.sh"
