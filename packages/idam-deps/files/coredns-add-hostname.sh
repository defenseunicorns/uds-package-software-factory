#!/bin/bash

NAMESPACE=kube-system
CONFIGMAP=coredns
DEPLOYMENT=coredns
TMP_FILE=tmp_cm.yaml

# Get list of gateways and their ip's
GATEWAYS=$(kubectl get svc -n istio-system -l istio=ingressgateway --sort-by='{.metadata.name}' --output=jsonpath='{range .items[*]}{.metadata.name}{"_"}{.status.loadBalancer.ingress[0].ip}{"\n"}{end}' | sed 's/keycloak/passthrough/g')

VIRTUALSERVICES=$(kubectl get vs -A -o=jsonpath='{range .items[*]}{.spec.gateways[*]}{"_"}{.spec.hosts[*]}{"\n"}{end}')

MAPPED_HOSTS=""

# Map virtualservices to their external ip
for gateway in $GATEWAYS; do
  for vs in $VIRTUALSERVICES; do
    if [ $(echo "$vs" | grep "$(echo $gateway | cut -d '-' -f1)" | wc -l) -gt 0 ]; then
      MAPPED_HOSTS="$MAPPED_HOSTS$(echo $gateway | cut -d '_' -f2) $(echo $vs | cut -d '_' -f2)\n      "
    fi
  done
done

# Wrap the mapped hosts in comments for tracking
MAPPED_HOSTS="#swf-begin\n      $MAPPED_HOSTS#swf-end"

# dump corefile into variable
COREFILE=$(kubectl get cm -n $NAMESPACE $CONFIGMAP -o jsonpath='{ .data.Corefile }')

# cleanup temp file if it exists
rm -f $TMP_FILE

# Check if a hosts block exists
if [ ! $(kubectl get cm -n $NAMESPACE $CONFIGMAP -o yaml | grep "hosts.*{" | wc -l) -gt 0 ]; then
  # if doesn't exist add hosts block after `kubernetes` block

  # build the string to insert
  read -r -d '' INSERT_STRING << EOF
  hosts {
      $(echo -e "$MAPPED_HOSTS")
      fallthrough
    }
EOF

  echo insert string
  echo -e "$INSERT_STRING"

  # escape newlines
  INSERT_STRING="${INSERT_STRING//$'\n'/\\n}"
  
  # Create new Corefile with hosts block
  COREFILE_NEW=$(echo "$COREFILE" | sed -Ez "s/kubernetes/$INSERT_STRING\n    &/")
else
  COREFILE="$(echo "$COREFILE" | sed -z 's/#swf-begin.*#swf-end//')"
  # if exists add hostname and ip to existing hosts block
  COREFILE_NEW=$(echo "$COREFILE" | sed -E "s/hosts.*/&\n      $(echo "$MAPPED_HOSTS")/")
fi

# build a configmap patch
cat << EOF > $TMP_FILE
data:
  Corefile: |
$(while IFS= read -r line; do printf '%4s%s\n' '' "$line"; done <<< "$COREFILE_NEW")
EOF

cat $TMP_FILE

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
