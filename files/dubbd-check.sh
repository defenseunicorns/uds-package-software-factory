#!/bin/bash

MINIMUM_VERSION= ###ZARF_PKG_TMPL_MIN_DUBBD_VERSION###

# Adds "━" for each character in minimum version number
for (( i=0; i<${#MINIMUM_VERSION}; i++ )); do
  LENGTH=$(printf "%s━" "$LENGTH")
done

# Get older of two versions
OLDER_VERSION=$(echo -e "${1}\n${MINIMUM_VERSION}" | sort -V | head -n1)

# If statement that handles if the version is older or not than the minimum version
if [[ "${OLDER_VERSION}" != "${MINIMUM_VERSION}" ]]; then
  printf "\033[1;91m┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s━┓\033[0m\n" "$LENGTH"
  printf "\033[1;91m┃ dubbd is older than minimum version: %s ┃\033[0m\n" "$MINIMUM_VERSION"
  printf "\033[1;91m┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s━┛\033[0m\n" "$LENGTH"
  echo
  exit 1
else
  printf "\033[1;92m┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓\033[0m\n"
  printf "\033[1;92m┃ dubbd meets minimum version ┃\033[0m\n"
  printf "\033[1;92m┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛\033[0m\n"
  echo
  exit 0
fi
