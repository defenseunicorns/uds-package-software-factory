#!/bin/bash

HOST_LIST=$(kubectl get vs -A -o=jsonpath='{range .items[*]}{.spec.gateways[*]}{" "}{.spec.hosts[*]}{"\n"}{end}' | sort -u)

TENANT_HOSTS=$(echo "${HOST_LIST}" | grep tenant | cut -d ' ' -f2)
ADMIN_HOSTS=$(echo "${HOST_LIST}" | grep admin | cut -d ' ' -f2)

TENANT_LB_IP=$(kubectl get svc -n istio-system tenant-ingressgateway -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
ADMIN_LB_IP=$(kubectl get svc -n istio-system admin-ingressgateway -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "# Following entries are from metallb dns.sh" >> hosts.patch

echo "# Tenant hostnames" >> hosts.patch

for host in $TENANT_HOSTS; do
    echo "${TENANT_LB_IP} ${host}" >> hosts.patch
done

echo "# Admin hostnames" >> hosts.patch

for host in $ADMIN_HOSTS; do
    echo "${ADMIN_LB_IP} ${host}" >> hosts.patch
done

echo "# End of metallb dns.sh" >> hosts.patch
