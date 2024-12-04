#!/bin/bash

get_tmc_clusters() {
  tmc_clusters=()
  refresh_token="$VMW_CLOUD_API_TOKEN"
  tcsp_url="https://console.tanzu.broadcom.com/csp/gateway/am/api/auth/api-tokens/authorize"
  tmc_url="https://mapbusupport.tmc.cloud.vmware.com"

  # Log start time
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting TMC cluster retrieval"

  # Get access token with timeout handling and x-request-id logging
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Retrieving access token..."
  status_code=$(curl -s -w "%{http_code}" --connect-timeout 10 -X POST -H "Accept: application/json" -H "Content-Type: application/x-www-form-urlencoded" --data-urlencode "refresh_token=$refresh_token" "$tcsp_url" -o response.json -D headers.txt)
  if [[ $? -eq 28 ]]; then
    request_id=$(grep -oE 'csp-request-id: [a-zA-Z0-9-]+' headers.txt | awk '{print $2}')
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Timeout error occurred while retrieving access token. x-request-id: $request_id"
    return 1
  fi

  access_token=$(jq -r '.access_token' response.json)

  echo "$(date '+%Y-%m-%d %H:%M:%S') - Status code (access token request): $status_code"

  if [ -n "$access_token" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Access token retrieved and validated."
  else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Failed to retrieve or validate access token. Check the status code above."
    return 1
  fi

  # Get management clusters with timeout handling and x-request-id logging
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Retrieving management clusters..."
  management_clusters_status_code=$(curl -s -w "%{http_code}" --connect-timeout 10 -X GET -H "Authorization: Bearer $access_token" "$tmc_url/v1alpha1/managementclusters" -o response.json -D headers.txt)
  if [[ $? -eq 28 ]]; then
    request_id=$(grep -oE 'x-request-id: [a-zA-Z0-9-]+' headers.txt | awk '{print $2}')
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Timeout error occurred while retrieving management clusters. x-request-id: $request_id"
    return 1
  fi

  echo "$(date '+%Y-%m-%d %H:%M:%S') - Management clusters API status code: $management_clusters_status_code"

  management_clusters=$(jq -r '.managementClusters[].fullName.name' response.json | sort)

  for management_cluster in $management_clusters; do
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Processing management cluster: $management_cluster"

    # Get provisioners with timeout handling and x-request-id logging
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Retrieving provisioners for $management_cluster..."
    provisioners_status_code=$(curl -s -w "%{http_code}" --connect-timeout 10 -X GET -H "Authorization: Bearer $access_token" "$tmc_url/v1alpha1/managementclusters/$management_cluster/provisioners" -o response.json -D headers.txt)
    if [[ $? -eq 28 ]]; then
      request_id=$(grep -oE 'x-request-id: [a-zA-Z0-9-]+' headers.txt | awk '{print $2}')
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Timeout error occurred while retrieving provisioners for $management_cluster. x-request-id: $request_id"
      continue
    fi

    echo "$(date '+%Y-%m-%d %H:%M:%S') - Provisioners API status code: $provisioners_status_code"

    provisioners=$(jq -r '.provisioners[].fullName.name' response.json | sort)

    for provisioner in $provisioners; do
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Processing provisioner: $provisioner"

      # Get TMC clusters with timeout handling and x-request-id logging
      echo "$(date '+%Y-%m-%d %H:%M:%S') - Retrieving TMC clusters for $provisioner..."
      tmc_cluster_status_code=$(curl -s -w "%{http_code}" --connect-timeout 10 -X GET -H "Authorization: Bearer $access_token" "$tmc_url/v1alpha1/managementclusters/$management_cluster/provisioners/$provisioner/tanzukubernetesclusters" -o response.json -D headers.txt)
      if [[ $? -eq 28 ]]; then
        request_id=$(grep -oE 'x-request-id: [a-zA-Z0-9-]+' headers.txt | awk '{print $2}')
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Timeout error occurred while retrieving TMC clusters for $provisioner. x-request-id: $request_id"
        continue
      fi

      echo "$(date '+%Y-%m-%d %H:%M:%S') - TMC clusters API status code: $tmc_cluster_status_code"

      tmc_cluster=$(jq -r '.tanzuKubernetesClusters[].fullName.name' response.json | sort)
      tmc_clusters+=("$tmc_cluster")
    done
  done

  echo "$(date '+%Y-%m-%d %H:%M:%S') - Finished TMC cluster retrieval"
  echo "${tmc_clusters[@]}"
}

while true; do
  get_tmc_clusters
  sleep 5
done
