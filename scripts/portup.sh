#!/bin/bash

THE_BASH_SOURCE=$BASH_SOURCE
READ_LINK=$(readlink -f $THE_BASH_SOURCE)
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
export VOLUMESDIR="$BASEDIR/volumes"

if [ "$1" == "system" ] | [ "$1" == "" ]; then
    SERVICES=$(kubectl get services --context devops | grep -i "NodePort" | tr -s " " | cut -f 1 -d" ")
    for SERVICE in $SERVICES; do
        echo SERVICE $SERVICE portup
        if [ -f "$DESCRIPTORSDIR/$SERVICE.yaml" ]; then
            devops service portup $SERVICE
        fi
    done
else
    devops service portup $*
fi
