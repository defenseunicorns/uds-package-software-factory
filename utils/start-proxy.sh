#!/bin/bash

echo "Downloading Caddy"
wget --quiet --no-clobber https://github.com/caddyserver/caddy/releases/download/v2.7.4/caddy_2.7.4_linux_amd64.tar.gz

echo "Downloading bigbang.dev cert and key"
wget --quiet --no-clobber https://raw.githubusercontent.com/defenseunicorns/uds-package-dubbd/main/defense-unicorns-distro/bigbang.dev.key
wget --quiet --no-clobber https://raw.githubusercontent.com/defenseunicorns/uds-package-dubbd/main/defense-unicorns-distro/bigbang.dev.cert

echo "Unpacking Caddy"
tar -xzf caddy_2.7.4_linux_amd64.tar.gz caddy

echo "Getting list of virtual service hosts"
HOST_LIST=$(kubectl get vs -A -o=jsonpath='{range .items[*]}{.spec.gateways[*]}{" "}{.spec.hosts[*]}{"\n"}{end}' | sort -u)

TENANT_HOSTS=$(echo "${HOST_LIST}" | grep tenant | cut -d ' ' -f2)
ADMIN_HOSTS=$(echo "${HOST_LIST}" | grep admin | cut -d ' ' -f2)
PASSTHROUGH_HOSTS=$(echo "${HOST_LIST}" | grep passthrough | cut -d ' ' -f2)

echo "Building Caddyfile"

CADDYFILE=""

for host in $TENANT_HOSTS; do
    BUFFER="https://${host} {
	tls bigbang.dev.cert bigbang.dev.key
	reverse_proxy https://${host}:8881
}
"
    CADDYFILE="${CADDYFILE}${BUFFER}"
done

for host in $ADMIN_HOSTS; do
    BUFFER="https://${host} {
	tls bigbang.dev.cert bigbang.dev.key
	reverse_proxy https://${host}:8882
}
"
    CADDYFILE="${CADDYFILE}${BUFFER}"
done

for host in $PASSTHROUGH_HOSTS; do
    BUFFER="https://${host} {
	tls bigbang.dev.cert bigbang.dev.key
	reverse_proxy https://${host}:8883
}
"
    CADDYFILE="${CADDYFILE}${BUFFER}"
done

echo "${CADDYFILE}" > Caddyfile

echo "Getting all istio gateways"

TENANT_POD=$(kubectl get pod -n istio-system -l app=tenant-ingressgateway -o=jsonpath='{.items[0].metadata.name}')
ADMIN_POD=$(kubectl get pod -n istio-system -l app=admin-ingressgateway -o=jsonpath='{.items[0].metadata.name}')
KEYCLOAK_POD=$(kubectl get pod -n istio-system -l app=keycloak-ingressgateway -o=jsonpath='{.items[0].metadata.name}')

echo "Starting port-forwards"

# Port forward all istio gateways in background in a loop
while true; do kubectl port-forward "${TENANT_POD}"   8881:8443 -n istio-system; done > /dev/null 2>&1 &

while true; do kubectl port-forward "${ADMIN_POD}"    8882:8443 -n istio-system; done > /dev/null 2>&1 &

while true; do kubectl port-forward "${KEYCLOAK_POD}" 8883:8443 -n istio-system; done > /dev/null 2>&1 &

echo "Starting Caddy"

sudo ./caddy start
