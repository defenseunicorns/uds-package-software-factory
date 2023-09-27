#!/bin/bash

SPLIT_FILES=(./split_src_*)

for file in "${SPLIT_FILES[@]}"; do
  echo "Adding $file to ./uds-bundle-software-factory-demo-amd64.tar.zst"
  cat $file >> ./uds-bundle-software-factory-demo-amd64.tar.zst
done

echo "Verifying checksums"

ORIG_SUM=$1

NEW_SUM=$(md5sum ./uds-bundle-software-factory-demo-amd64.tar.zst)

if [ "$ORIG_SUM" == "$NEW_SUM" ]; then
  echo "Checksums match"
else
  echo "Checksums do not match"
  exit 1
fi