#!/bin/bash
#set -x

echo -e "Build environment variables:"
echo "REGISTRY_URL=${REGISTRY_URL}"
echo "REGISTRY_NAMESPACE=${REGISTRY_NAMESPACE}"
echo "IMAGE_NAME=${IMAGE_NAME}"
echo "BUILD_NUMBER=${BUILD_NUMBER}"
echo "ARCHIVE_DIR=${ARCHIVE_DIR}"

# Learn more about the available environment variables at:
# https://console.bluemix.net/docs/services/ContinuousDelivery/pipeline_deploy_var.html#deliverypipeline_environment

# To review or change build options use:
# bx cr build --help

echo "=========================================================="
echo "Checking for Dockerfile at the repository root"
if [ -f Dockerfile ]; then 
  echo "Dockerfile found"
else
    echo "Dockerfile not found"
    exit 1
fi

echo "=========================================================="
echo "Checking registry current plan and quota"
bx cr plan
bx cr quota
echo "If needed, discard older images using: bx cr image-rm"

echo "Checking registry namespace: ${REGISTRY_NAMESPACE}"
NS=$( bx cr namespaces | grep ${REGISTRY_NAMESPACE} ||: )
if [ -z "${NS}" ]; then
    echo "Registry namespace ${REGISTRY_NAMESPACE} not found, creating it."
    bx cr namespace-add ${REGISTRY_NAMESPACE}
    echo "Registry namespace ${REGISTRY_NAMESPACE} created."
else 
    echo "Registry namespace ${REGISTRY_NAMESPACE} found."
fi

echo -e "Existing images in registry"
bx cr images

echo "=========================================================="
echo -e "Building container image: ${IMAGE_NAME}:${BUILD_NUMBER}"
set -x
bx cr build -t ${REGISTRY_URL}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}:${BUILD_NUMBER} .
set +x
bx cr image-inspect ${REGISTRY_URL}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}:${BUILD_NUMBER}

# When 'bx' commands are in the pipeline job config directly, the image URL will automatically be passed 
# along with the build result as env variable PIPELINE_IMAGE_URL to any subsequent job consuming this build result. 
# When the job is sourc'ing an external shell script, or to pass a different image URL than the one inferred by the pipeline,
# please uncomment and modify the environment variable the following line.
# export PIPELINE_IMAGE_URL="$REGISTRY_URL/$REGISTRY_NAMESPACE/$IMAGE_NAME:$BUILD_NUMBER"

######################################################################################
# Copy any artifacts that will be needed for deployment and testing to $WORKSPACE    #
######################################################################################

echo -e "Retrieve the service instances for the toolchain"
TOOLCHAIN_SERVICES=$(curl -H "Authorization: ${TOOLCHAIN_TOKEN}" "${PIPELINE_API_URL%/pipeline}/toolchains/${PIPELINE_TOOLCHAIN_ID}/services")
GIT_REPO_SERVICE_ID=$(echo $TOOLCHAIN_SERVICES | jq --arg GIT_URL "${GIT_URL}" -r '.services[] | select(.parameters.repo_url==$GIT_URL) | .instance_id')

echo -e "Checking archive dir presence"
mkdir -p $ARCHIVE_DIR

# pass image information along via build.properties for Vulnerability Advisor scan
echo "IMAGE_NAME=${IMAGE_NAME}" >> $ARCHIVE_DIR/build.properties
echo "BUILD_NUMBER=${BUILD_NUMBER}" >> $ARCHIVE_DIR/build.properties
echo "REGISTRY_URL=${REGISTRY_URL}" >> $ARCHIVE_DIR/build.properties
echo "REGISTRY_NAMESPACE=${REGISTRY_NAMESPACE}" >> $ARCHIVE_DIR/build.properties
echo "SOURCE_GIT_URL=${GIT_URL}" >> $ARCHIVE_DIR/build.properties
echo "SOURCE_GIT_BRANCH=${GIT_BRANCH}" >> $ARCHIVE_DIR/build.properties
echo "SOURCE_GIT_REVISION_URL=${GIT_URL%.git}/commit/${GIT_COMMIT}" >> $ARCHIVE_DIR/build.properties
SOURCE_GIT_REVISION_TIMESTAMP=$(date +%s)
echo "SOURCE_GIT_REVISION_TIMESTAMP=${SOURCE_GIT_REVISION_TIMESTAMP}" >> $ARCHIVE_DIR/build.properties
echo "GIT_REPO_SERVICE_ID=${GIT_REPO_SERVICE_ID}" >> $ARCHIVE_DIR/build.properties
echo "File 'build.properties' created for passing env variables to subsequent pipeline jobs:"
cat $ARCHIVE_DIR/build.properties      

#Update deployment.yml with image name
if [ -f deployment.yml ]; then
    echo "UPDATING DEPLOYMENT MANIFEST:"
    sed -i "s~^\([[:blank:]]*\)image:.*$~\1image: ${REGISTRY_URL}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}:${BUILD_NUMBER}~" deployment.yml
    cat deployment.yml
    if [ ! -f $ARCHIVE_DIR/deployment.yml ]; then # no need to copy if working in ./ already    
        cp deployment.yml $ARCHIVE_DIR/
    fi
else 
    echo -e "${red}Kubernetes deployment file 'deployment.yml' not found at the repository root${no_color}"
    exit 1
fi      
