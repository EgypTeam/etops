#!/bin/bash

SERVICENAME=$1

BINPATH=$(dirname -- "$BASH_SOURCE")
DELETEPORTFORWARDSERVICE="$BINPATH/delete-port-forward-service.sh"

$DELETEPORTFORWARDSERVICE $SERVICENAME

kubectl delete service $SERVICENAME
kubectl delete deployment $SERVICENAME
kubectl delete pvc $SERVICENAME
kubectl delete pv $SERVICENAME
