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


export PROJECT='mdwdops'
export DEPLOYMENT_ID='7862'
export AZURE_LOCATION='australiaeast'
export ENV_NAME='dev'
export AZURE_SUBSCRIPTION_ID='d3c00b3e-62a3-4d55-bed2-a0c29891af20'
export MSYS_NO_PATHCONV=1
resource_group_name="mdwdops-7865-dev-rg"
databricks_workspace_resource_id="/subscriptions/d3c00b3e-62a3-4d55-bed2-a0c29891af20/resourceGroups/mdwdops-7865-dev-rg/providers/Microsoft.Databricks/workspaces/mdwdops-dbw-dev-7865"

databricks_host="https://adb-9005977231308781.1.azuredatabricks.net"
kv_dns_name="https://mdwdops-kv-dev-7865.vault.azure.net/"

databricks_token="dapi39fa5b91cde710f7145fb9a901f022db"
azure_storage_key=""
azure_storage_account="mdwdopsstdev7865"

datafactory_name=""
sp_adf_id=""
sp_adf_pass=""
sp_adf_tenant=""

az login --tenant "9e375c99-a8c8-49a8-8127-1ea23e715cad"


az account set --subscription "$AZURE_SUBSCRIPTION_ID"
echo "--------------------STEP 4: Deploying AZDO variables to Subscription for Deployment ID :  -------------------"
'--------------------STEP 4: Deploying AZDO variables to Subscription for Deployment ID :  -------------------' $DEPLOYMENT_ID  >> variablevalues.log


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
#SQL_SERVER_NAME=$sql_server_name \
#SQL_SERVER_USERNAME=$sql_server_username \
#SQL_SERVER_PASSWORD=$AZURESQL_SERVER_PASSWORD \
#SQL_DW_DATABASE_NAME=$sql_dw_database_name \
AZURE_STORAGE_KEY=$azure_storage_key \
AZURE_STORAGE_ACCOUNT=$azure_storage_account \
DATAFACTORY_NAME=$datafactory_name \
SP_ADF_ID=$sp_adf_id \
SP_ADF_PASS=$sp_adf_pass \
SP_ADF_TENANT=$sp_adf_tenant \
    bash -c "./scripts/deploy_azdo_variables.sh"

echo "STEP 4: Deploying AZDO variables to Subscription completed successfully"







