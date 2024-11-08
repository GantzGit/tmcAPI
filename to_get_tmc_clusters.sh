#!/bin/bash

get_tmc_clusters() {
  tmc_clusters=()
  refresh_token="$VMW_CLOUD_API_TOKEN"
  url="https://console.tanzu.broadcom.com/csp/gateway/am/api/auth/api-tokens/authorize"

  # Log start time
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting TMC cluster retrieval"

  # Get access token with timeout handling
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Retrieving access token..."
  response=$(curl -s -w "%{http_code}" --connect-timeout 10 -X POST -H "Accept: application/json" -H "Content-Type: application/x-www-form-urlencoded" --data-urlencode "refresh_token=$refresh_token" "$url")
  if [[ $? -eq 28 ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Timeout error occurred while retrieving access token."
    return 1
  fi
  # Extract the access token using 'jq' only if the response is in JSON format
  if [[ "$response" == *'"access_token":'* ]]; then
    access_token=$(echo "$response" | jq -r '.access_token')
  else
    access_token="" # Set access_token to empty if it's not in JSON format
  fi  
  status_code=$(echo "$response" | tail -c 4) 

  # Output only the status code (removed full API response)
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Status code (access token request): $status_code"

  # Validate access token
  if [ -n "$access_token" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Access token retrieved and validated." 
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Failed to retrieve or validate access token. Check the status code above."
    return 1 
  fi

  # Get management clusters with timeout handling
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Retrieving management clusters..."
  management_clusters_response=$(curl -s -w "%{http_code}" --connect-timeout 10 -X GET -H "Authorization: Bearer $access_token" "https://mapbusupport.tmc.cloud.vmware.com/v1alpha1/managementclusters")
  if [[ $? -eq 28 ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Timeout error occurred while retrieving management clusters."
    return 1
  fi

  # Output only the status code (removed full API response)
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Management clusters API status code: $management_clusters_status_code"

  # Extract management clusters if the response is in JSON format
  if [[ "$management_clusters_response" == *'"managementClusters":'* ]]; then
    management_clusters=$(echo "$management_clusters_response" | jq -r '.managementClusters[].fullName.name' | sort)
  else
    management_clusters="" # Set management_clusters to empty if not in JSON format
  fi

  # Loop through management clusters
  for management_cluster in $management_clusters; do
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Processing management cluster: $management_cluster"

    # Get provisioners with timeout handling
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Retrieving provisioners for $management_cluster..."
    provisioners_response=$(curl -s -w "%{http_code}" --connect-timeout 10 -X GET -H "Authorization: Bearer $access_token" "https://mapbusupport.tmc.cloud.vmware.com/v1alpha1/managementclusters/$management_cluster/provisioners")
    if [[ $? -eq 28 ]]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Timeout error occurred while retrieving provisioners for $management_cluster."
      continue # Skip to the next management cluster
    fi
    provisioners_status_code=$(echo "$provisioners_response" | tail -c 4)

    # Output only the status code (removed full API response)
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Provisioners API status code: $provisioners_status_code"

    # Extract provisioners if the response is in JSON format
    if [[ "$provisioners_response" == *'"provisioners":'* ]]; then
      provisioners=$(echo "$provisioners_response" | jq -r '.provisioners[].fullName.name' | sort)
    else
      provisioners="" # Set provisioners to empty if not in JSON format
    fi

    # Loop through provisioners
    for provisioner in $provisioners; do
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Processing provisioner: $provisioner"

      # Get TMC clusters with timeout handling
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Retrieving TMC clusters for $provisioner..."
      tmc_cluster_response=$(curl -s -w "%{http_code}" --connect-timeout 10 -X GET -H "Authorization: Bearer $access_token" "https://mapbusupport.tmc.cloud.vmware.com/v1alpha1/managementclusters/$management_cluster/provisioners/$provisioner/tanzukubernetesclusters")
      if [[ $? -eq 28 ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Timeout error occurred while retrieving TMC clusters for $provisioner."
        continue # Skip to the next provisioner
      fi
      tmc_cluster_status_code=$(echo "$tmc_cluster_response" | tail -c 4)

      # Output the status code for TMC clusters API call
      echo "$(date '+%Y-%m-%d %H:%M:%S') - TMC clusters API status code: $tmc_cluster_status_code"

      # Extract TMC clusters if the response is in JSON format
      if [[ "$tmc_cluster_response" == *'"tanzuKubernetesClusters":'* ]]; then
        tmc_cluster=$(echo "$tmc_cluster_response" | jq -r '.tanzuKubernetesClusters[].fullName.name' | sort)
        tmc_clusters+=("$tmc_cluster")
      else
        # Output the full response and specific error message for debugging
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Failed to retrieve TMC clusters. Full API response: $tmc_cluster_response" 
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Check the response for details or try running the following command manually:"
        echo "curl -s -X GET -H \"Authorization: Bearer $access_token\" \"https://mapbusupport.tmc.cloud.vmware.com/v1alpha1/managementclusters/$management_cluster/provisioners/$provisioner/tanzukubernetesclusters\""
      fi
    done
  done

  echo "$(date '+%Y-%m-%d %H:%M:%S') - Finished TMC cluster retrieval"
  echo "${tmc_clusters[@]}"
}

while true; do
  get_tmc_clusters
  sleep 5 # Wait for 5 seconds before the next iteration
done