#!/bin/bash

SERVICENAME=$1

BINPATH=$(dirname -- "$BASH_SOURCE")
CREATEPORTFORWARDSERVICE="$BINPATH/create-port-forward-service.sh"

kubectl apply -f $BINPATH/../local/$SERVICENAME.yaml

$CREATEPORTFORWARDSERVICE $SERVICENAME
