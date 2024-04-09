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

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace # For debugging
export MSYS_NO_PATHCONV=1
# REQUIRED VARIABLES:
#
# DATABRICKS_HOST
# DATABRICKS_TOKEN - this needs to be a Azure AD user token (not PAT token or Azure AD application token that belongs to a service principal)
# KEYVAULT_RESOURCE_ID
# KEYVAULT_DNS_NAME

#DATABRICKS_TOKEN='eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsIng1dCI6ImtXYmthYTZxczh3c1RuQndpaU5ZT2hIYm5BdyIsImtpZCI6ImtXYmthYTZxczh3c1RuQndpaU5ZT2hIYm5BdyJ9.eyJhdWQiOiIyZmY4MTRhNi0zMzA0LTRhYjgtODVjYi1jZDBlNmY4NzljMWQiLCJpc3MiOiJodHRwczovL3N0cy53aW5kb3dzLm5ldC85ZTM3NWM5OS1hOGM4LTQ5YTgtODEyNy0xZWEyM2U3MTVjYWQvIiwiaWF0IjoxNzA3NjM3NzkwLCJuYmYiOjE3MDc2Mzc3OTAsImV4cCI6MTcwNzY0MjU5MiwiYWNyIjoiMSIsImFpbyI6IkFZUUFlLzhWQUFBQXE3QTdXSmJicE9FQUoxby9TU0kzNi9ybHJGQXpla2lZVHF2QlFUNWxQRlJBbVV2cFIrUDJPeVB0ajJTOGttem5RS1ArWVJ4WnBoNS9YdHJ1dlpXNmFHOE9uZnIxdXhIT3NGTFd6eTE3Y3p4bUxtSkhXVEM3aTdJV21iSllqem54TUhkQUh4eWxaNTI5VnZaWS80ZlBoRjk3OTI4NUc0Tml4a1JmcXhXVFBDRT0iLCJhbHRzZWNpZCI6IjE6bGl2ZS5jb206MDAwNjdGRkU5QUUwMDcyRSIsImFtciI6WyJwd2QiLCJtZmEiXSwiYXBwaWQiOiIwNGIwNzc5NS04ZGRiLTQ2MWEtYmJlZS0wMmY5ZTFiZjdiNDYiLCJhcHBpZGFjciI6IjAiLCJlbWFpbCI6ImdhZ2FucmthcG9vckBob3RtYWlsLmNvbSIsImZhbWlseV9uYW1lIjoiS2Fwb29yIiwiZ2l2ZW5fbmFtZSI6IkdhZ2FuIiwiaWRwIjoibGl2ZS5jb20iLCJpcGFkZHIiOiIyMDMuMjE5LjE5Ni4xNDYiLCJuYW1lIjoiR2FnYW4gS2Fwb29yIEhvdG1haWwiLCJvaWQiOiJiZDNlN2ZkYi01NGU0LTRmMzMtOWRmYy04MDMwOGQyODgwMDUiLCJwdWlkIjoiMTAwMzIwMDIxMDM4RTlEMiIsInJoIjoiMC5BV1lBbVZ3M25zaW9xRW1CSng2aVBuRmNyYVlVLUM4RU03aEtoY3ZORG0tSG5CMW1BSUkuIiwic2NwIjoidXNlcl9pbXBlcnNvbmF0aW9uIiwic3ViIjoiQ2xjdGJINHZVbkpYRzRXRlZENlgyZWpJR21UQklzaC1mbWlMZlhmVzBZQSIsInRpZCI6IjllMzc1Yzk5LWE4YzgtNDlhOC04MTI3LTFlYTIzZTcxNWNhZCIsInVuaXF1ZV9uYW1lIjoibGl2ZS5jb20jZ2FnYW5ya2Fwb29yQGhvdG1haWwuY29tIiwidXRpIjoiQkpzVnFONTlBMDIzYXZzR2thWTdBQSIsInZlciI6IjEuMCJ9.iGKiVzA5N8fLvRZqTdwbe8acXWLM_po3gjA2c6g9rIFfc3DesE6mvZR6kzG0zOdIQ183Jhq4A8DRXI6tniTXHpiXhnJ4286SQku1VRDtJTsXz8ti4ak9bw9YGIVp6v-s8HQ99IIcryzddraWHsj7mU5cdZIZQfJM0yhvp97-KbXh5xlXs0WOmEC2G4VIDNOS0s1IMIiSaalLRfs9jzCd0hC8GXiHnje5yfz1OlEosgonzEnbl5EuuSMx8Ayb0Ffic8hqHlo7OrRy7YJ7dodQU4nJoLtscmKcaJ3JWVJB1AY9w-9UyHaqwMWgo83f87Bg-PyGZfS9H3wLR07kep6EnA'
#DATABRICKS_HOST='https://adb-9005977231308781.1.azuredatabricks.net/'
KEYVAULT_DNS_NAME="https://mdwdops-kv-dev-7123.vault.azure.net/"
KEYVAULT_RESOURCE_ID='/subscriptions/d3c00b3e-62a3-4d55-bed2-a0c29891af20/resourceGroups/mdwdops-7123-dev-rg/providers/Microsoft.KeyVault/vaults/mdwdops-kv-dev-7123'


wait_for_run () {
    # See here: https://docs.azuredatabricks.net/api/latest/jobs.html#jobsrunresultstate
    declare mount_run_id=$1
    while : ; do
        life_cycle_status=$(databricks runs get --run-id "$mount_run_id" | jq -r ".state.life_cycle_state") 
        result_state=$(databricks runs get --run-id "$mount_run_id" | jq -r ".state.result_state")
        if [[ $result_state == "SUCCESS" || $result_state == "SKIPPED" ]]; then
            break;
        elif [[ $life_cycle_status == "INTERNAL_ERROR" || $result_state == "FAILED" ]]; then
            state_message=$(databricks runs get --run-id "$mount_run_id" | jq -r ".state.state_message")
            echo -e "${RED}Error while running ${mount_run_id}: ${state_message} ${NC}"
            exit 1
        else 
            echo "Waiting for run ${mount_run_id} to finish..."
            sleep 1m
        fi
    done
}


cluster_exists () {
    declare cluster_name="$1"
    declare cluster=$(databricks clusters list | tr -s " " | cut -d" " -f2 | grep ^${cluster_name}$)
    if [[ -n $cluster ]]; then
        return 0; # cluster exists
    else
        return 1; # cluster does not exists
    fi
}

echo "Configuring Databricks workspace."
# Create secret scope, if not exists
scope_name="storage_scope"
if [[ ! -z $(databricks secrets list-scopes | grep "$scope_name") ]]; then
    # Delete existing scope
    # NOTE: Need to recreate everytime to ensure idempotent deployment. Reruning deployment overrides KeyVault permissions.
    echo "Scope already exists, re-creating secrets scope: $scope_name"
    databricks secrets delete-scope --scope "$scope_name"    
fi
# Create secret scope
echo "will create scope in 1 mins"
echo $KEYVAULT_RESOURCE_ID
sleep 1m
databricks secrets create-scope --scope "$scope_name" \
    --scope-backend-type AZURE_KEYVAULT \
    --resource-id "$KEYVAULT_RESOURCE_ID" \
    --dns-name "$KEYVAULT_DNS_NAME" \

# Upload notebooks
echo "Uploading notebooks..."
databricks workspace import_dir "./databricks/notebooks" "/notebooks" --overwrite

# Setup workspace
echo "Setting up workspace and tables. This may take a while as cluster spins up..."
wait_for_run $(databricks runs submit --json-file "./databricks/config/run.setup.config.json" | jq -r ".run_id" )
 

# Upload libs -- for initial dev package
# Needs to run AFTER mounting dbfs:/mnt/datalake in setup workspace
echo "Uploading libs..."
databricks fs cp --recursive --overwrite "./databricks/libs/" "dbfs:/mnt/datalake/sys/databricks/libs/"



# Create initial cluster, if not yet exists
cluster_config="./databricks/config/cluster.config.json"
echo "Creating an interactive cluster using config in $cluster_config..."
cluster_name=$(cat "$cluster_config" | jq -r ".cluster_name")
if cluster_exists "$cluster_name"; then 
    echo "Cluster ${cluster_name} already exists!"
else
    echo "Creating cluster ${cluster_name}..."
    echo "will create Cluster in 5 mins"
    sleep 5m
    databricks clusters create --json-file $cluster_config
fi

echo "Completed configuring databricks."