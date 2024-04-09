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
export DEPLOYMENT_ID='7865'
export ENV_NAME='dev'
export AZURE_LOCATION='australiaeast'
export AZURE_SUBSCRIPTION_ID='d3c00b3e-62a3-4d55-bed2-a0c29891af20'
export AZURESQL_SERVER_PASSWORD='Allity@123'
export MSYS_NO_PATHCONV=1

# Set account to where ARM template will be deployed to
echo "Deploying to Subscription: $AZURE_SUBSCRIPTION_ID"
az account set --subscription "$AZURE_SUBSCRIPTION_ID"

####################
# DATA FACTORY

databricks_host="https://adb-9005977231308781.1.azuredatabricks.net"
databricks_workspace_resource_id="9005977231308781"
#databricks_aad_token="eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsIng1dCI6ImtXYmthYTZxczh3c1RuQndpaU5ZT2hIYm5BdyIsImtpZCI6ImtXYmthYTZxczh3c1RuQndpaU5ZT2hIYm5BdyJ9.eyJhdWQiOiIyZmY4MTRhNi0zMzA0LTRhYjgtODVjYi1jZDBlNmY4NzljMWQiLCJpc3MiOiJodHRwczovL3N0cy53aW5kb3dzLm5ldC85ZTM3NWM5OS1hOGM4LTQ5YTgtODEyNy0xZWEyM2U3MTVjYWQvIiwiaWF0IjoxNzA3NDMzMzI4LCJuYmYiOjE3MDc0MzMzMjgsImV4cCI6MTcwNzQzNzYxNSwiYWNyIjoiMSIsImFpbyI6IkFZUUFlLzhWQUFBQVd3b3F1VmFmS3FUc0FBV2pKaHk5Z2xPNFFDT0JZNWk2elpveFAydUIwN0FxVWVrOTVBdTljcG5vU20rdlpsN2F4RTV3MXdZSVVXeHpJV0tyaXM1ekNSdFUyOFQ0ZEJkeWVQL0U2UUZwNnovOGJxTENCbDd2K0lmaGplNkRhUllYbitsUEZrQWxoeEVCZ0w0VFdxUGMyZnJKM1VwSDc5UGpySGpwdks5UFNiND0iLCJhbHRzZWNpZCI6IjE6bGl2ZS5jb206MDAwNjdGRkU5QUUwMDcyRSIsImFtciI6WyJwd2QiLCJtZmEiXSwiYXBwaWQiOiIwNGIwNzc5NS04ZGRiLTQ2MWEtYmJlZS0wMmY5ZTFiZjdiNDYiLCJhcHBpZGFjciI6IjAiLCJlbWFpbCI6ImdhZ2FucmthcG9vckBob3RtYWlsLmNvbSIsImZhbWlseV9uYW1lIjoiS2Fwb29yIiwiZ2l2ZW5fbmFtZSI6IkdhZ2FuIiwiaWRwIjoibGl2ZS5jb20iLCJpcGFkZHIiOiIyMDMuMjE5LjE5Ni4xNDYiLCJuYW1lIjoiR2FnYW4gS2Fwb29yIEhvdG1haWwiLCJvaWQiOiJiZDNlN2ZkYi01NGU0LTRmMzMtOWRmYy04MDMwOGQyODgwMDUiLCJwdWlkIjoiMTAwMzIwMDIxMDM4RTlEMiIsInJoIjoiMC5BV1lBbVZ3M25zaW9xRW1CSng2aVBuRmNyYVlVLUM4RU03aEtoY3ZORG0tSG5CMW1BSUkuIiwic2NwIjoidXNlcl9pbXBlcnNvbmF0aW9uIiwic3ViIjoiQ2xjdGJINHZVbkpYRzRXRlZENlgyZWpJR21UQklzaC1mbWlMZlhmVzBZQSIsInRpZCI6IjllMzc1Yzk5LWE4YzgtNDlhOC04MTI3LTFlYTIzZTcxNWNhZCIsInVuaXF1ZV9uYW1lIjoibGl2ZS5jb20jZ2FnYW5ya2Fwb29yQGhvdG1haWwuY29tIiwidXRpIjoiUW9NS195bVJLazZrTkRfSzFUcGxBQSIsInZlciI6IjEuMCJ9.WXgUdeYZBBOBWzKMwk7X5coEwVKH2E8xrqoTswDa8DQCRTmX-A_WXhol70k0aC-ScR5fZVaJgrnxz3lSxbe7UFdCe-bQ81-q-2l0IKBK23WGJt8y7J3Qk0N5L8zj43ZZHfNQzXttIQtMqMXL3IO_lR4D3zcWywfSZQBmIxRrv6FpQy_Twa2AP_pkzotxI_q--BC43tICODH3cNu-ROEHY-kgfv9w8KIqVvmv-EyH-eRcP2EZzYUZiSsvmjRHYF5zwZLn9ahZIbBB3h76FRCwkLzGnxfHbcp4F1H1KjWWLJn6yLK_VM2r_nfPVFHOiIsn1UAokhFRkgtzHyxOXw3T4w"
databricks_token="dapi39fa5b91cde710f7145fb9a901f022db"
kv_dns_name="https://mdwdops-kv-dev-7865.vault.azure.net/" 
#kv_resource_id="/subscriptions/d3c00b3e-62a3-4d55-bed2-a0c29891af20/resourceGroups/mdwdops-7865-dev-rg/providers/Microsoft.KeyVault/vaults/mdwdops-kv-dev-7865" 
kv_name="mdwdops-kv-dev-7865" 
azure_storage_account="mdwdopsstdev7865"
datafactory_name="mdwdops-adf-dev-7865"
resource_group_name="mdwdops-7865-dev-rg"
adfTempDir=.tmp/adf

# Deploy ADF artifacts
AZURE_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID \
RESOURCE_GROUP_NAME=$resource_group_name \
DATAFACTORY_NAME=$datafactory_name \
ADF_DIR=$adfTempDir \
    bash -c "./deploy_adf_artifacts.sh"

# ADF SP for integration tests
sp_adf_name="${PROJECT}-adf-${ENV_NAME}-${DEPLOYMENT_ID}-sp"
sp_adf_out=$(az ad sp create-for-rbac \
    --role "Data Factory contributor" \
    --scopes "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$resource_group_name/providers/Microsoft.DataFactory/factories/$datafactory_name" \
    --name "$sp_adf_name" \
    --output json)
sp_adf_id=$(echo "$sp_adf_out" | jq -r '.appId')
sp_adf_pass=$(echo "$sp_adf_out" | jq -r '.password')
sp_adf_tenant=$(echo "$sp_adf_out" | jq -r '.tenant')

# Save ADF SP credentials in Keyvault
az keyvault secret set --vault-name "$kv_name" --name "spAdfName" --value "$sp_adf_name"
az keyvault secret set --vault-name "$kv_name" --name "spAdfId" --value "$sp_adf_id"
az keyvault secret set --vault-name "$kv_name" --name "spAdfPass" --value "$sp_adf_pass"
az keyvault secret set --vault-name "$kv_name" --name "spAdfTenantId" --value "$sp_adf_tenant"

echo "Completed deploying Azure resources $resource_group_name ($ENV_NAME)"

   
# AZDO Azure Service Connection and Variables Groups

# AzDO Azure Service Connections
PROJECT=$PROJECT \
ENV_NAME=$ENV_NAME \
RESOURCE_GROUP_NAME=$resource_group_name \
DEPLOYMENT_ID=$DEPLOYMENT_ID \
    bash -c "./scripts/deploy_azdo_service_connections_azure.sh"

# AzDO Variable Groups
PROJECT=$PROJECT \
ENV_NAME=$ENV_NAME \
AZURE_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID \
RESOURCE_GROUP_NAME=$resource_group_name \
AZURE_LOCATION=$AZURE_LOCATION \
KV_URL=$kv_dns_name \
DATABRICKS_TOKEN=$databricks_token \
DATABRICKS_HOST=$databricks_host \
DATABRICKS_WORKSPACE_RESOURCE_ID=$databricks_workspace_resource_id \
SQL_SERVER_NAME=$sql_server_name \
SQL_SERVER_USERNAME=$sql_server_username \
SQL_SERVER_PASSWORD=$AZURESQL_SERVER_PASSWORD \
SQL_DW_DATABASE_NAME=$sql_dw_database_name \
AZURE_STORAGE_KEY=$azure_storage_key \
AZURE_STORAGE_ACCOUNT=$azure_storage_account \
DATAFACTORY_NAME=$datafactory_name \
SP_ADF_ID=$sp_adf_id \
SP_ADF_PASS=$sp_adf_pass \
SP_ADF_TENANT=$sp_adf_tenant \
    bash -c "./scripts/deploy_azdo_variables.sh"


####################
# BUILD ENV FILE FROM CONFIG INFORMATION

env_file=".env.${ENV_NAME}"
echo "Appending configuration to .env file."
cat << EOF >> "$env_file"

# ------ Configuration from deployment on ${TIMESTAMP} -----------
RESOURCE_GROUP_NAME=${resource_group_name}
AZURE_LOCATION=${AZURE_LOCATION}
SQL_SERVER_NAME=${sql_server_name}
SQL_SERVER_USERNAME=${sql_server_username}
SQL_SERVER_PASSWORD=${AZURESQL_SERVER_PASSWORD}
SQL_DW_DATABASE_NAME=${sql_dw_database_name}
AZURE_STORAGE_ACCOUNT=${azure_storage_account}
AZURE_STORAGE_KEY=${azure_storage_key}
SP_STOR_NAME=${sp_stor_name}
SP_STOR_ID=${sp_stor_id}
SP_STOR_PASS=${sp_stor_pass}
SP_STOR_TENANT=${sp_stor_tenant}
DATABRICKS_HOST=${databricks_host}
DATABRICKS_TOKEN=${databricks_token}
DATAFACTORY_NAME=${datafactory_name}
APPINSIGHTS_KEY=${appinsights_key}
KV_URL=${kv_dns_name}

EOF
echo "Completed deploying Azure resources $resource_group_name ($ENV_NAME)"

