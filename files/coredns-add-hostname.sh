#!/bin/bash

NAMESPACE=kube-system
CONFIGMAP=coredns
DEPLOYMENT=coredns
HOSTNAME=keycloak.###ZARF_VAR_DOMAIN###
SERVICE_NS=istio-system
SERVICE=keycloak-ingressgateway
TMP_FILE=tmp_cm.yaml

# Get service external ip
IP=$(kubectl get svc $SERVICE -n $SERVICE_NS -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# dump corefile into variable
COREFILE=$(kubectl get cm -n $NAMESPACE $CONFIGMAP -o jsonpath='{ .data.Corefile }')

# Check if hostname is already in hosts block
if [ $(echo "$COREFILE" | grep "$HOSTNAME" | wc -l) -gt 0 ]; then
  echo "Hostname already exists in hosts block - bailing"
  exit 0
fi

# cleanup temp file if it exists
rm -f $TMP_FILE

# Check if a hosts block exists
if [ ! $(kubectl get cm -n $NAMESPACE $CONFIGMAP -o yaml | grep "hosts.*{" | wc -l) -gt 0 ]; then
  # if doesn't exist add hosts block after `kubernetes` block

  # build the string to insert
  read -r -d '' INSERT_STRING << EOF
  hosts {
      $IP $HOSTNAME
      fallthrough
    }
EOF

  # escape newlines
  INSERT_STRING="${INSERT_STRING//$'\n'/\\n}"
  
  # Create new Corefile with hosts block
  COREFILE_NEW=$(echo "$COREFILE" | sed -Ez "s/kubernetes/$INSERT_STRING\n    &/")
else
  # if exists add hostname and ip to existing hosts block
  COREFILE_NEW=$(echo "$COREFILE" | sed -E "s/hosts.*/&\n       $IP $HOSTNAME/")
fi

# build a configmap patch
cat << EOF > $TMP_FILE
data:
  Corefile: |
$(while IFS= read -r line; do printf '%4s%s\n' '' "$line"; done <<< "$COREFILE_NEW")
EOF

# apply the configmap
echo "Attempting to apply the following ConfigMap patch:"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
cat $TMP_FILE
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
kubectl patch configmap -n $NAMESPACE $CONFIGMAP --patch-file $TMP_FILE

# restart coredns
kubectl rollout restart -n $NAMESPACE deployment/$DEPLOYMENT

# cleanup the tmp file
rm -f $TMP_FILE
