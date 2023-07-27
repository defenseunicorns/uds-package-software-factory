#!/bin/bash

MINIMUM_VERSION="0.5.0"

DEPLOYED_VERSION=$(kubectl get secret -n zarf --no-headers=true | awk '/dubbd/{print $1}' | xargs kubectl get secret -n zarf -o=jsonpath='{.data.data}' | base64 -d | jq -r .data.metadata.version)

# Get newer of two versions
OLDER_VERSION=$(echo -e "${DEPLOYED_VERSION}\n${MINIMUM_VERSION}" | sort -V | head -n1)

if [[ "${OLDER_VERSION}" != "${MINIMUM_VERSION}" ]]; then
  echo "dubbd is older than minimum version: $MINIMUM_VERSION"
  exit 1
else
  echo "dubbd version meets minimum requirement"
  exit 0
fi
