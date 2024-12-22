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

PODNAME=$(kubectl get pods | head -2 | tail -1 | tr -s " " | cut -f1 -d" " | grep -E "^$SERVICE\\.*")
echo $SERVICE
echo $PODNAME

if [ "$PODNAME" != "" ]; then

    kubectl exec -it $PODNAME /bin/bash

fi
