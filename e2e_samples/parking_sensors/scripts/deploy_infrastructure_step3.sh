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
export DEPLOYMENT_ID='7123'
export ENV_NAME='dev'
export AZURE_SUBSCRIPTION_ID='d3c00b3e-62a3-4d55-bed2-a0c29891af20'
export MSYS_NO_PATHCONV=1
resource_group_name="mdwdops-7123-dev-rg"
databricks_workspace_resource_id="/subscriptions/d3c00b3e-62a3-4d55-bed2-a0c29891af20/resourceGroups/mdwdops-7123-dev-rg/providers/Microsoft.Databricks/workspaces/mdwdops-dbw-dev-7123"
azure_storage_account="mdwdopsstdev7123"
databricks_host="https://adb-1930589843615996.16.azuredatabricks.net"
kv_dns_name="https://mdwdops-kv-dev-7123.vault.azure.net/"
datafactory_name="mdwdops-adf-dev-7123"
kv_name="mdwdops-kv-dev-7123"

echo "--------------------STEP 3: Deploying ADF to subscription for Deployment ID: ------------------- $DEPLOYMENT_ID"  
echo '--------------------STEP 3: Deploying ADF to subscription for Deployment ID: -------------------' $DEPLOYMENT_ID  >> variablevalues.log
####################
# DATA FACTORY
echo "Deploying ADF to Subscription: $AZURE_SUBSCRIPTION_ID"
az account set --subscription "$AZURE_SUBSCRIPTION_ID"

echo '--------------------Starting the deployment of Deployment ID STEP 2 :  -------------------' $DEPLOYMENT_ID  >> variablevalues.log
echo "Updating Data Factory LinkedService to point to newly deployed resources (KeyVault and DataLake)."
# Create a copy of the ADF dir into a .tmp/ folder.
adfTempDir=.tmp/adf
mkdir -p $adfTempDir && cp -a adf/ .tmp/
# Update ADF LinkedServices to point to newly deployed Datalake URL, KeyVault URL, and Databricks workspace URL
tmpfile=.tmpfile
adfLsDir=$adfTempDir/linkedService
jq --arg kvurl "$kv_dns_name" '.properties.typeProperties.baseUrl = $kvurl' $adfLsDir/Ls_KeyVault_01.json > "$tmpfile" && mv "$tmpfile" $adfLsDir/Ls_KeyVault_01.json
jq --arg databricksWorkspaceUrl "$databricks_host" '.properties.typeProperties.domain = $databricksWorkspaceUrl' $adfLsDir/Ls_AzureDatabricks_01.json > "$tmpfile" && mv "$tmpfile" $adfLsDir/Ls_AzureDatabricks_01.json
jq --arg databricksWorkspaceResourceId "$databricks_workspace_resource_id" '.properties.typeProperties.workspaceResourceId = $databricksWorkspaceResourceId' $adfLsDir/Ls_AzureDatabricks_01.json > "$tmpfile" && mv "$tmpfile" $adfLsDir/Ls_AzureDatabricks_01.json
jq --arg datalakeUrl "https://$azure_storage_account.dfs.core.windows.net" '.properties.typeProperties.url = $datalakeUrl' $adfLsDir/Ls_AdlsGen2_01.json > "$tmpfile" && mv "$tmpfile" $adfLsDir/Ls_AdlsGen2_01.json

#datafactory_name=$(echo "$arm_output" | jq -r '.properties.outputs.datafactory_name.value')
az keyvault secret set --vault-name "$kv_name" --name "adfName" --value "$datafactory_name"
echo '**** --- datafactory_name :  '$datafactory_name >> variablevalues.log

# Deploy ADF artifacts
AZURE_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID \
RESOURCE_GROUP_NAME=$resource_group_name \
DATAFACTORY_NAME=$datafactory_name \
ADF_DIR=$adfTempDir \
    bash -c "./scripts/deploy_adf_artifacts.sh"

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

echo '**** --- spAdfName :  '$sp_adf_name >> variablevalues.log
echo '**** --- spAdfId :  '$sp_adf_id >> variablevalues.log
echo '**** --- spAdfPass :  '$sp_adf_pass >> variablevalues.log
echo '**** --- sp_adf_tenant :  '$sp_adf_tenant >> variablevalues.log

# Save ADF SP credentials in Keyvault
az keyvault secret set --vault-name "$kv_name" --name "spAdfName" --value "$sp_adf_name"
az keyvault secret set --vault-name "$kv_name" --name "spAdfId" --value "$sp_adf_id"
az keyvault secret set --vault-name "$kv_name" --name "spAdfPass" --value "$sp_adf_pass"
az keyvault secret set --vault-name "$kv_name" --name "spAdfTenantId" --value "$sp_adf_tenant"

echo "STEP 3: Deploying ADF to subscription completed successfully"





