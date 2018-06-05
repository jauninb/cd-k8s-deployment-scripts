#!/bin/bash

# Extract the related GIT var from build.properties
while read -r line ; do
    echo "Processing $line"
    eval "export $line"
done < <(grep GIT build.properties)

deploymapping_template=$(cat <<'EOT'
{
    "deployable": {
        "deployable_guid": "%s",
        "type": "app",
        "region_id": "%s",
        "organization_guid": "8d34d127-d3db-43cd-808b-134b388f1646",
        "space_guid": "5f9f2e5f-610c-4013-b34c-84c6bf4ccf30"
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
printf "$deploymapping_template" "$TARGET_DEPLOYABLE_GUID" "$TARGET_REGION_ID" \
  "${PIPELINE_TOOLCHAIN_ID}" "$TARGET_REGION_ID" \
  "${PIPELINE_ID}" \
  "${GIT_REPO_SERVICE_ID}" "${SOURCE_GIT_URL}" "${SOURCE_GIT_BRANCH}" "${SOURCE_GIT_REVISION_TIMESTAMP}" "$SOURCE_GIT_REVISION_URL" \
  "${PIPELINE_CLUSTER_NAME}" "${CLUSTER_NAMESPACE}" > deployable_mapping.json

echo -e "POST ${PIPELINE_API_URL%/pipeline}/toolchain_deployable_mappings"
cat deployable_mapping.json

curl -X POST \
  "${PIPELINE_API_URL%/pipeline}/toolchain_deployable_mappings" \
  -is \
  -H "Authorization: ${TOOLCHAIN_TOKEN}" \
  -H "cache-control: no-cache" \
  -H "content-type: application/json; charset=utf-8" \
  -d @deployable_mapping.json
