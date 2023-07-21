#!/bin/bash

sed -i -z 's/\n# Following entries are from metallb dns.sh.*# End of metallb dns.sh//' /etc/hosts

cat hosts.patch >> /etc/hosts
