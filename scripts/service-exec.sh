#!/bin/bash

THE_BASH_SOURCE=$BASH_SOURCE
READ_LINK=$(readlink $THE_BASH_SOURCE)
if [ "$READ_LINK" != "" ]; then
    THE_BASH_SOURCE=$READ_LINK
fi

SERVICEPATH=$1
SCOPE=$(echo $SERVICEPATH | cut -f1 -d"/")
SERVICE=$(echo $SERVICEPATH | cut -f2 -d"/")
if [ "$SERVICE" == "" ]; then
    SERVICE=$SCOPE
    SCOPE=default
fi
SCOMMAND=${@:2}
if [ "$SCOMMAND" == "" ]; then
    SCOMMAND=/bin/sh
fi
BINDIR=$(dirname $THE_BASH_SOURCE)
BASEDIR=$(dirname $BINDIR)
SCRIPTSDIR="$BASEDIR/scripts"
DESCRIPTORSDIR="$BASEDIR/descriptors/$SCOPE"

PODNAME=$(kubectl get pods --context etops | grep -E "^$SERVICE\\.*" | tr -s " " | cut -f1 -d" ")

if [ "$PODNAME" != "" ]; then

    kubectl exec -it $PODNAME -- $SCOMMAND

fi
