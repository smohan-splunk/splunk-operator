#!/bin/bash
# Script to update OLM bundles in deploy/olm-catalog and deploy/olm-certified

# exit when any command fails
set -e

VERSION=`grep "Version.*=.*\".*\"" version/version.go | sed "s,.*Version.*=.*\"\(.*\)\".*,\1,"`
DOCKER_IO_PATH="docker.io/splunk"
REDHAT_REGISTRY_PATH="registry.connect.redhat.com/splunk"
OPERATOR_IMAGE="$DOCKER_IO_PATH/splunk-operator:${VERSION}"
OLM_CATALOG=deploy/olm-catalog
OLM_CERTIFIED=deploy/olm-certified
YAML_SCRIPT_FILE=.yq_script.yaml

RESOURCES="
  - kind: StatefulSets
    version: apps/v1
  - kind: Deployments
    version: apps/v1
  - kind: Pods
    version: v1
  - kind: Services
    version: v1
  - kind: ConfigMaps
    version: v1
  - kind: Secrets
    version: v1
"

cat << EOF >$YAML_SCRIPT_FILE
- command: update
  path: spec.install.spec.deployments[0].spec.template.spec.containers[0].image
  value: $OPERATOR_IMAGE
- command: update
  path: spec.install.spec.permissions[0].serviceAccountName
  value: splunk-operator
- command: update
  path: spec.customresourcedefinitions.owned[0].resources
  value: $RESOURCES
- command: update
  path: spec.customresourcedefinitions.owned[1].resources
  value: $RESOURCES
- command: update
  path: spec.customresourcedefinitions.owned[2].resources
  value: $RESOURCES
- command: update
  path: spec.customresourcedefinitions.owned[3].resources
  value: $RESOURCES
- command: update
  path: spec.customresourcedefinitions.owned[4].resources
  value: $RESOURCES
- command: update
  path: spec.customresourcedefinitions.owned[0].displayName
  value: IndexerCluster
- command: update
  path: spec.customresourcedefinitions.owned[1].displayName
  value: LicenseMaster
- command: update
  path: spec.customresourcedefinitions.owned[2].displayName
  value: SearchHeadCluster
- command: update
  path: spec.customresourcedefinitions.owned[3].displayName
  value: Spark
- command: update
  path: spec.customresourcedefinitions.owned[4].displayName
  value: Standalone
- command: update
  path: metadata.annotations.alm-examples
  value: |-
    [{
      "apiVersion": "enterprise.splunk.com/v1alpha2",
      "kind": "IndexerCluster",
      "metadata": {
        "name": "example",
        "finalizers": [ "enterprise.splunk.com/delete-pvc" ]
      },
      "spec": {
        "replicas": 1
      }
    },
    {
      "apiVersion": "enterprise.splunk.com/v1alpha2",
      "kind": "LicenseMaster",
      "metadata": {
        "name": "example",
        "finalizers": [ "enterprise.splunk.com/delete-pvc" ]
      },
      "spec": {}
    },
    {
      "apiVersion": "enterprise.splunk.com/v1alpha2",
      "kind": "SearchHeadCluster",
      "metadata": {
        "name": "example",
        "finalizers": [ "enterprise.splunk.com/delete-pvc" ]
      },
      "spec": {
        "replicas": 1
      }
    },
    {
      "apiVersion": "enterprise.splunk.com/v1alpha2",
      "kind": "Spark",
      "metadata": {
        "name": "example"
      },
      "spec": {
        "replicas": 1
      }
    },
    {
      "apiVersion": "enterprise.splunk.com/v1alpha2",
      "kind": "Standalone",
      "metadata": {
        "name": "example",
        "finalizers": [ "enterprise.splunk.com/delete-pvc" ]
      },
      "spec": {}
    }]
EOF

echo Updating $OLM_CATALOG
operator-sdk generate csv --csv-version $VERSION --operator-name splunk --update-crds --verbose
yq w -i -s $YAML_SCRIPT_FILE $OLM_CATALOG/splunk/$VERSION/splunk.v${VERSION}.clusterserviceversion.yaml
rm -f $YAML_SCRIPT_FILE

echo Updating $OLM_CERTIFIED
rm -rf $OLM_CERTIFIED
mkdir -p $OLM_CERTIFIED/splunk
cp $OLM_CATALOG/splunk/$VERSION/*_crd.yaml $OLM_CERTIFIED/splunk/
yq w $OLM_CATALOG/splunk/$VERSION/splunk.v${VERSION}.clusterserviceversion.yaml metadata.certified "true" > $OLM_CERTIFIED/splunk/splunk.v${VERSION}.clusterserviceversion.yaml
yq w $OLM_CATALOG/splunk/splunk.package.yaml packageName "splunk-certified" > $OLM_CERTIFIED/splunk/splunk.package.yaml
sed -i '' "s,$DOCKER_IO_PATH/spark,$REDHAT_REGISTRY_PATH/spark,g" $OLM_CERTIFIED/splunk/splunk.v${VERSION}.clusterserviceversion.yaml
zip $OLM_CERTIFIED/splunk.zip -j $OLM_CERTIFIED/splunk $OLM_CERTIFIED/splunk/*
