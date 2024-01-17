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

export GITHUB_REPO="gaganrkapoor/modern-data-warehouse-dataops"
export GITHUB_PAT_TOKEN="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"
export RESOURCE_GROUP_LOCATION='australiaeast'
export AZURE_SUBSCRIPTION_ID='d3c00b3e-62a3-4d55-bed2-a0c29891af20'
export RESOURCE_GROUP_NAME_PREFIX='mdwdo-azadf'
export DEPLOYMENT_ID='3136'
export AZDO_PIPELINES_BRANCH_NAME='main'
export MSYS_NO_PATHCONV=1


az login --tenant "9e375c99-a8c8-49a8-8127-1ea23e715cad"



. ./scripts/common.sh
. ./scripts/verify_prerequisites.sh
. ./scripts/init_environment.sh


project=mdwdops # CONSTANT - this is prefixes to all resources of the Parking Sensor sample
github_repo_url="https://github.com/$GITHUB_REPO"

bash -c "./scripts/deploy_infrastructure.sh"




print_style "DEPLOYMENT SUCCESSFUL
Details of the deployment can be found in local .env.* files.\n\n" "success"

print_style "IMPORTANT:
This script has updated your local Azure Pipeline YAML definitions to point to your Github repo.
ACTION REQUIRED: Commit and push up these changes to your Github repo before proceeding.\n\n" "warning"

echo "See README > Setup and Deployment for more details and next steps." 