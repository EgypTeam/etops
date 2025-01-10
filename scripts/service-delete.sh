#!/bin/bash

THE_BASH_SOURCE=$BASH_SOURCE
READ_LINK=$(readlink $THE_BASH_SOURCE)
if [ "$READ_LINK" != "" ]; then
    THE_BASH_SOURCE=$READ_LINK
fi

if [ "$2" == "" ]; then
    SCOPE=default
    SERVICE=$1
else
    SCOPE=$1
    SERVICE=$2
fi

etops service portdown $SERVICE

BINDIR=$(dirname $THE_BASH_SOURCE)
BASEDIR=$(dirname $BINDIR)
SCRIPTSDIR="$BASEDIR/scripts"
DESCRIPTORSDIR="$BASEDIR/descriptors/$SCOPE"
BEFORECREATEDIR="$BASEDIR/confscripts-before-create"
AFTERDELETEDIR="$BASEDIR/confscripts-after-delete"
export VOLUMESDIR="$BASEDIR/volumes"

envsubst < $DESCRIPTORSDIR/$SERVICE.yaml | kubectl delete -f - --context etops

if [ -f "$AFTERDELETEDIR/$SERVICE.sh" ]; then
    "$AFTERDELETEDIR/$SERVICE.sh"
fi
