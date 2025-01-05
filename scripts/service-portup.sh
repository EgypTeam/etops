#!/bin/bash

SERVICENAME=$1
SERVICETARGETPORTS=$(kubectl get service --profile etops $SERVICENAME | tail -1 | tr -s " " | cut -f5 -d" " | tr "," "\\n" | cut -f 1 -d:)

for SERVICETARGETPORT in $SERVICETARGETPORTS; do
    echo "Port: $SERVICETARGETPORT"
    (kubectl port-forward service/$SERVICENAME --profile etops --address 0.0.0.0 $SERVICETARGETPORT:$SERVICETARGETPORT >/dev/null 2> /dev/null) &
    #(kubectl port-forward service/$SERVICENAME --profile etops --address 0.0.0.0 $SERVICETARGETPORT:$SERVICETARGETPORT)
done
