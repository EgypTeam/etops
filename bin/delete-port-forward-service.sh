#!/bin/bash

#sysctl net.ipv4.ip_unprivileged_port_start=0

SERVICENAME=$1
SERVICETARGETPORT=$(kubectl get services nginx-service | tail -1 | tr -s " " | cut -f5 -d" " | cut -f 1 -d:)
SERVICEPORT=$2
if [ "$SERVICEPORT" == "" ]; then
    SERVICEPORT=$SERVICETARGETPORT
fi
PID=$(ps aux | grep -E "[0-9] kubectl port-forward" | grep -i " $SERVICEPORT:" | tr -s " " | cut -f 2 -d" ")
if [ "$PID" != "" ]; then
    kill -9 $PID
fi