#!/bin/bash

list_management_clusters() {
  refresh_token="$VMW_CLOUD_API_TOKEN"
  url="https://console.tanzu.broadcom.com/csp/gateway/am/api/auth/api-tokens/authorize?refresh_token=$refresh_token"

  # Log start time
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting management cluster retrieval"

  # Get access token
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Retrieving access token..."
  access_token=$(curl -s -X POST -H "Content-Type: application/json" "$url" | jq -r '.access_token')

  # Validate access token
  if [ -n "$access_token" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Access token retrieved and validated."
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Failed to retrieve or validate access token. Check your refresh token."
    return 1 # Exit the function with an error code
  fi

  # Get management clusters
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Retrieving management clusters..."
  management_clusters=$(curl -s -X GET -H "Authorization: Bearer $access_token" "https://mapbusupport.tmc.cloud.vmware.com/v1alpha1/managementclusters" | jq -r '.managementClusters[].fullname.name' | sort)

  # List management clusters
  if [ -n "$management_clusters" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Management clusters found:"
    for cluster in $management_clusters; do
      echo "- $cluster"
    done
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - No management clusters found."
  fi

  echo "$(date '+%Y-%m-%d %H:%M:%S') - Finished management cluster retrieval"
}

list_management_clusters