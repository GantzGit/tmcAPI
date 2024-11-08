#!/bin/bash

get_provisioners() {
  management_cluster="mgmt-v251-etomohisa" 
  refresh_token="$VMW_CLOUD_API_TOKEN"
  url="https://console.tanzu.broadcom.com/csp/gateway/am/api/auth/api-tokens/authorize"

  # Log start time
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting provisioner retrieval for $management_cluster"

  # Get access token
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Retrieving access token..."
  response=$(curl -s -w "%{http_code}" -X POST -H "Accept: application/json" -H "Content-Type: application/x-www-form-urlencoded" --data-urlencode "refresh_token=$refresh_token" "$url")
  # Extract the access token using 'jq' only if the response is in JSON format
  if [[ "$response" == *'"access_token":'* ]]; then
    access_token=$(echo "$response" | jq -r '.access_token')
  else
    access_token="" # Set access_token to empty if it's not in JSON format
  fi  
  status_code=$(echo "$response" | tail -c 4) 

  # Output the full response and status code
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Full API response: $response"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Status code: $status_code"

  # Validate access token
  if [ -n "$access_token" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Access token retrieved and validated: $access_token" 
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Failed to retrieve or validate access token. Check the full API response and status code above."
    return 1 
  fi

  # Get provisioners
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Retrieving provisioners for $management_cluster..."
  provisioners_response=$(curl -s -w "%{http_code}" -X GET -H "Authorization: Bearer $access_token" "https://mapbusupport.tmc.cloud.vmware.com/v1alpha1/managementclusters/$management_cluster/provisioners")
  provisioners_status_code=$(echo "$provisioners_response" | tail -c 4)

  # Output the full response and status code for provisioners API call
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Full provisioners API response: $provisioners_response"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Provisioners API status code: $provisioners_status_code"

  # Extract provisioners ONLY if the response is in JSON format and contains "provisioners"
  if [[ "$provisioners_response" == *'"provisioners":'* ]]; then
    provisioners=$(echo "$provisioners_response" | jq -r '.provisioners[].fullName.name' | sort) 
  else
    provisioners="" # Set provisioners to empty if not in JSON format
  fi

  # List provisioners
  if [ -n "$provisioners" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Provisioners found for $management_cluster:"
    for provisioner in $provisioners; do
      echo "- $provisioner"
    done
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - No provisioners found for $management_cluster."
  fi

  echo "$(date '+%Y-%m-%d %H:%M:%S') - Finished provisioner retrieval"
}

get_provisioners