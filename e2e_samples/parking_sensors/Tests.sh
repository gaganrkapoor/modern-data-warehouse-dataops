#!/bin/bash
export AZURE_SUBSCRIPTION_ID='d3c00b3e-62a3-4d55-bed2-a0c29891af20'
export MSYS_NO_PATHCONV=1
echo "enter your choice to deploy"
read choice
if [ "$choice" = "1" ] 
then
    az login --tenant "9e375c99-a8c8-49a8-8127-1ea23e715cad"
    databricks_aad_token=$(az account get-access-token --resource 2ff814a6-3304-4ab8-85cb-cd0e6f879c1d --output json | jq -r .accessToken)
    echo "in first condition"
    echo $databricks_aad_token
    export DATABRICKS_AAD_TOKEN=$databricks_aad_token
    export DATABRICKS_HOST='https://adb-9005977231308781.1.azuredatabricks.net'  
    databricks configure --jobs-api-version 2.1 --host $DATABRICKS_HOST --aad-token;

elif [ "$choice" = "2" ]
then
    cd scripts/
    echo "Executing the script 2";

elif [ "$choice" = "3" ]
then
    echo "executing 3"   
fi


echo "See README > Setup and Deployment for more details and next steps." 