#!/bin/bash

MINIMUM_VERSION="0.5.0"

for (( i=0; i<${#MINIMUM_VERSION}; i++ )); do
  LENGTH=$(printf "%s━" "$LENGTH")
done

DEPLOYED_VERSION=$(kubectl get secret -n zarf --no-headers=true | awk '/dubbd/{print $1}' | xargs kubectl get secret -n zarf -o=jsonpath='{.data.data}' | base64 -d | jq -r .data.metadata.version)

# Get newer of two versions
OLDER_VERSION=$(echo -e "${DEPLOYED_VERSION}\n${MINIMUM_VERSION}" | sort -V | head -n1)

if [[ "${OLDER_VERSION}" != "${MINIMUM_VERSION}" ]]; then
  printf "\033[1;91m┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s━┓\033[0m\n" "$LENGTH"
  printf "\033[1;91m┃ dubbd is older than minimum version: %s ┃\033[0m\n" "$MINIMUM_VERSION"
  printf "\033[1;91m┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s━┛\033[0m\n" "$LENGTH"
  echo
  exit 1
else
  printf "\033[1;92m┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓\033[0m\n"
  printf "\033[1;92m┃ dubbd meets minimum requirement ┃\033[0m\n"
  printf "\033[1;92m┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛\033[0m\n"
  echo
  exit 0
fi
