#!/bin/bash

SERVICENAME=$1
SERVICETARGETPORT=$(kubectl get services $SERVICENAME | tail -1 | tr -s " " | cut -f5 -d" " | cut -f 1 -d:)
SERVICEPORT=$2
if [ "$SERVICEPORT" == "" ]; then
    SERVICEPORT=$SERVICETARGETPORT
fi

echo "Port: $SERVICEPORT"

(kubectl port-forward service/$SERVICENAME --address 0.0.0.0 $SERVICEPORT:$SERVICETARGETPORT >/dev/null 2> /dev/null) &

#echo kubectl port-forward service/$SERVICENAME --address 0.0.0.0 $SERVICEPORT:$SERVICETARGETPORT
#kubectl port-forward service/$SERVICENAME --address 0.0.0.0 $SERVICEPORT:$SERVICETARGETPORT

