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

BINDIR=$(dirname $THE_BASH_SOURCE)
BASEDIR=$(dirname $BINDIR)
SCRIPTSDIR="$BASEDIR/scripts"
DESCRIPTORSDIR="$BASEDIR/descriptors/$SCOPE"
BEFORECREATEDIR="$BASEDIR/confscripts-before-create"
AFTERDELETEDIR="$BASEDIR/confscripts-after-delete"

if [ -f "$BEFORECREATEDIR/$SERVICE.sh" ]; then
    source "$BEFORECREATEDIR/$SERVICE.sh"
fi

envsubst < $DESCRIPTORSDIR/$SERVICE.yaml | kubectl apply -f - --context etops

sleep 10

etops service portup $SERVICE

