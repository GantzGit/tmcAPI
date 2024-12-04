#!/bin/bash

get_tmc_clusters() {
  tmc_clusters=()
  refresh_token="$VMW_CLOUD_API_TOKEN"
  url="https://console.tanzu.broadcom.com/csp/gateway/am/api/auth/api-tokens/authorize"

  # Log start time
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting TMC cluster retrieval"

  # Get access token with timeout handling and x-request-id logging
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Retrieving access token..."
  response=$(curl -s -w "%{http_code}" --connect-timeout 10 -X POST -H "Accept: application/json" -H "Content-Type: application/x-www-form-urlencoded" --data-urlencode "refresh_token=$refresh_token" "$url")
  if [[ $? -eq 28 ]]; then
    request_id=$(echo "$response" | grep -oE 'x-request-id: [a-zA-Z0-9-]+' | awk '{print $2}')
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Timeout error occurred while retrieving access token. x-request-id: $request_id"
    return 1
  fi

  if [[ "$response" == *'"access_token":'* ]]; then
    access_token=$(echo "$response" | jq -r '.access_token')
  else
    access_token="" 
  fi  
  status_code=$(echo "$response" | tail -c 4) 

  echo "$(date '+%Y-%m-%d %H:%M:%S') - Status code (access token request): $status_code"

  if [ -n "$access_token" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Access token retrieved and validated." 
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Failed to retrieve or validate access token. Check the status code above."
    return 1 
  fi

  # Get management clusters with timeout handling and x-request-id logging
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Retrieving management clusters..."
  management_clusters_response=$(curl -s -w "%{http_code}" --connect-timeout 10 -X GET -H "Authorization: Bearer $access_token" "https://mapbusupport.tmc.cloud.vmware.com/v1alpha1/managementclusters")
  if [[ $? -eq 28 ]]; then
    request_id=$(echo "$management_clusters_response" | grep -oE 'x-request-id: [a-zA-Z0-9-]+' | awk '{print $2}')
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Timeout error occurred while retrieving management clusters. x-request-id: $request_id"
    return 1
  fi

  echo "$(date '+%Y-%m-%d %H:%M:%S') - Management clusters API status code: $management_clusters_status_code"

  if [[ "$management_clusters_response" == *'"managementClusters":'* ]]; then
    management_clusters=$(echo "$management_clusters_response" | jq -r '.managementClusters[].fullName.name' | sort)
  else
    management_clusters="" 
  fi

  for management_cluster in $management_clusters; do
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Processing management cluster: $management_cluster"

    # Get provisioners with timeout handling and x-request-id logging
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Retrieving provisioners for $management_cluster..."
    provisioners_response=$(curl -s -w "%{http_code}" --connect-timeout 10 -X GET -H "Authorization: Bearer $access_token" "https://mapbusupport.tmc.cloud.vmware.com/v1alpha1/managementclusters/$management_cluster/provisioners")
    if [[ $? -eq 28 ]]; then
      request_id=$(echo "$provisioners_response" | grep -oE 'x-request-id: [a-zA-Z0-9-]+' | awk '{print $2}')
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Timeout error occurred while retrieving provisioners for $management_cluster. x-request-id: $request_id"
      continue 
    fi
    
    provisioners_status_code=$(echo "$provisioners_response" | tail -c 4)

    echo "$(date '+%Y-%m-%d %H:%M:%S') - Provisioners API status code: $provisioners_status_code"

    if [[ "$provisioners_response" == *'"provisioners":'* ]]; then
      provisioners=$(echo "$provisioners_response" | jq -r '.provisioners[].fullName.name' | sort)
    else
      provisioners="" 
    fi

    for provisioner in $provisioners; do
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Processing provisioner: $provisioner"

      # Get TMC clusters with timeout handling and x-request-id logging
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Retrieving TMC clusters for $provisioner..."
      tmc_cluster_response=$(curl -s -w "%{http_code}" --connect-timeout 10 -X GET -H "Authorization: Bearer $access_token" "https://mapbusupport.tmc.cloud.vmware.com/v1alpha1/managementclusters/$management_cluster/provisioners/$provisioner/tanzukubernetesclusters")
      if [[ $? -eq 28 ]]; then
        request_id=$(echo "$tmc_cluster_response" | grep -oE 'x-request-id: [a-zA-Z0-9-]+' | awk '{print $2}')
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Timeout error occurred while retrieving TMC clusters for $provisioner. x-request-id: $request_id"
        continue 
      fi
      tmc_cluster_status_code=$(echo "$tmc_cluster_response" | tail -c 4)

      echo "$(date '+%Y-%m-%d %H:%M:%S') - TMC clusters API status code: $tmc_cluster_status_code"

      if [[ "$tmc_cluster_response" == *'"tanzuKubernetesClusters":'* ]]; then
        tmc_cluster=$(echo "$tmc_cluster_response" | jq -r '.tanzuKubernetesClusters[].fullName.name' | sort)
        tmc_clusters+=("$tmc_cluster")
      else
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
  sleep 5 
done