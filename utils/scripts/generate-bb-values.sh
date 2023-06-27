#!/bin/bash

# Simple help message
if [ "$1" == "-h" ] ||[ "$1" == "--help" ] || [ -z "$1" ] || [ -z "$2" ] || [ ! -z "$3" ]; then
  echo "Usage: `basename $0` <path to values file> <name of app/bb package>"
  exit 0
fi

# Set variables to script args
LOCAL_VALUES="$1"
PACKAGE="$2"

# If version isn't set get the latest from github
if [ -z "${DUBBD_VERSION}" ]; then
  DUBBD_VERSION=$(curl -s https://api.github.com/repos/defenseunicorns/uds-package-dubbd/releases/latest | jq -c .tag_name | tr -d '"')
fi

# Set the zarf config from dubbd to a variable
DUBBD_ZARF_CONFIG=$(curl -s https://raw.githubusercontent.com/defenseunicorns/uds-package-dubbd/"${DUBBD_VERSION}"/defense-unicorns-distro/zarf-config.yaml)

# Set the zarf.yaml from dubbd to a variable
DUBBD_ZARF=$(curl -s https://raw.githubusercontent.com/defenseunicorns/uds-package-dubbd/"${DUBBD_VERSION}"/defense-unicorns-distro/zarf.yaml)

# A template for referencing dubbd values
VALUES_URL_TMPL="https:\/\/raw.githubusercontent.com\/defenseunicorns\/uds-package-dubbd\/"${DUBBD_VERSION}"\/values\/"

# Get the current bigbang version from the dubbd zarf.yaml
BB_VERSION=$(echo "${DUBBD_ZARF_CONFIG}" | yq .package.create.set.bigbang_version)

# Using the VALUES_URL_TMPL and the dubbd zarf.yaml get the list of values files and format them as arguments to `helm template`
VALUES_ARGS=$(echo "${DUBBD_ZARF}" | yq '.components[] | select(.name == "bigbang") | .extensions.bigbang.valuesFiles[]' | xargs | sed "s/\.\.\/values\//-f ${VALUES_URL_TMPL}/g")

# Clones a temporary BigBang Chart to use for `helm template` and places it in the /tmp/bigbang-app-values directory
# Uses same BigBang version as dubbd
git clone --depth 1 --branch "${BB_VERSION}" https://repo1.dso.mil/big-bang/bigbang.git /tmp/bigbang-app-values &> /dev/null

# Templates the chart based off of provided values for the desired package and dubbd defaults, then generates a ${PACKAGE}-values.yaml for the desired package
helm template bigbang /tmp/bigbang-app-values/chart ${VALUES_ARGS} -f ${LOCAL_VALUES} | yq "select(.metadata.name == \"bigbang-${PACKAGE}-values\") | .stringData.defaults" > ${PACKAGE}-values.yaml

# Removes temporary BigBang chart
rm -rf /tmp/bigbang-app-values

echo "App values have been placed in ./${PACKAGE}-values.yaml"