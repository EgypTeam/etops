#!/bin/bash

#sysctl net.ipv4.ip_unprivileged_port_start=0

SERVICENAME=$1
SERVICETARGETPORT=$(kubectl get services nginx-service | tail -1 | tr -s " " | cut -f5 -d" " | cut -f 1 -d:)
SERVICEPORT=$2
if [ "$SERVICEPORT" == "" ]; then
    SERVICEPORT=$SERVICETARGETPORT
fi
(kubectl port-forward services/$SERVICENAME --address 0.0.0.0 $SERVICEPORT:$SERVICETARGETPORT >/dev/null 2> /dev/null) &

