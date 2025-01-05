#!/bin/bash

#sysctl net.ipv4.ip_unprivileged_port_start=0

SERVICENAME=$1
SERVICETARGETPORTS=$(kubectl get service --context etops $SERVICENAME | tail -1 | tr -s " " | cut -f5 -d" " | tr "," "\\n" | cut -f 1 -d:)

for SERVICETARGETPORT in $SERVICETARGETPORTS; do
    echo "Port: $SERVICETARGETPORT"
    PID=$(ps aux | grep -E "[0-9] kubectl port-forward --context etops" | grep -i " $SERVICETARGETPORT:" | tr -s " " | cut -f 2 -d" ")
    if [ "$PID" != "" ]; then
        kill -9 $PID
    fi
done
