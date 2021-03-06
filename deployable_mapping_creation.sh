#!/bin/bash

# Extract the related GIT var from build.properties
while read -r line ; do
    echo "Processing $line"
    eval "export $line"
done < <(grep GIT build.properties)

# If creating a deployable mapping of type non app, ui is failing/showing internal error
deploymapping_template=$(cat <<'EOT'
{
    "deployable": {
        "deployable_guid": "%s",
        "type": "app",
        "region_id": "%s",
        "organization_guid": "%s"
    },
    "toolchain": {
        "toolchain_guid": "%s",
        "region_id": "%s"
    },
    "source": {
        "type": "service_instance",
        "source_guid": "%s"
    },
    "experimental": {
        "inputs": [{
            "service_instance_id": "%s",
            "data": {
                "repo_url": "%s",
                "repo_branch": "%s",
                "timestamp": "%s",
                "revision_url": "%s"
            }
        }],
        "env": {
            "label": "%s:%s"
        }
    }
}
EOT
)

echo -e "Create the deployable mapping payload"
printf "$deploymapping_template" "$TARGET_DEPLOYABLE_GUID" "$TARGET_REGION_ID" "$PIPELINE_ORGANIZATION_ID" \
  "${PIPELINE_TOOLCHAIN_ID}" "$TARGET_REGION_ID" \
  "${PIPELINE_ID}" \
  "${GIT_REPO_SERVICE_ID}" "${SOURCE_GIT_URL}" "${SOURCE_GIT_BRANCH}" "${SOURCE_GIT_REVISION_TIMESTAMP}" "$SOURCE_GIT_REVISION_URL" \
  "${PIPELINE_KUBERNETES_CLUSTER_NAME}" "${CLUSTER_NAMESPACE}" > deployable_mapping.json

echo -e "Identify the HTTP verb to use"
EXISTING_DEPLOYABLE_MAPPINGS=$(curl -H "Authorization: ${TOOLCHAIN_TOKEN}" "${PIPELINE_API_URL%/pipeline}/toolchain_deployable_mappings?toolchain_guid=${PIPELINE_TOOLCHAIN_ID}")
MAPPING_GUID=$(echo $EXISTING_DEPLOYABLE_MAPPINGS | jq --arg DEPLOYABLE_GUID "$TARGET_DEPLOYABLE_GUID" -r '.items[] | select(.deployable.deployable_guid==$DEPLOYABLE_GUID) | .mapping_guid');

echo "MAPPING_GUID=$MAPPING_GUID"

if [ -z "$MAPPING_GUID" ]; then
   HTTP_VERB="POST"
else 
   HTTP_VERB="PUT"
   COMPLEMENTARY_PATH="/${MAPPING_GUID}"
fi

echo -e "$HTTP_VERB ${PIPELINE_API_URL%/pipeline}/toolchain_deployable_mappings${COMPLEMENTARY_PATH}"
cat deployable_mapping.json

curl -X $HTTP_VERB \
  "${PIPELINE_API_URL%/pipeline}/toolchain_deployable_mappings${COMPLEMENTARY_PATH}" \
  -is \
  -H "Authorization: ${TOOLCHAIN_TOKEN}" \
  -H "cache-control: no-cache" \
  -H "content-type: application/json; charset=utf-8" \
  -d @deployable_mapping.json
