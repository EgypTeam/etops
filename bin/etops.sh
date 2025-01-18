#!/bin/bash

if [ "$1" == "" ]; then
    echo "Missing command class"
    exit 1
fi

THE_BASH_SOURCE=$BASH_SOURCE
READ_LINK=$(readlink -f $THE_BASH_SOURCE)
if [ "$READ_LINK" != "" ]; then
    THE_BASH_SOURCE=$READ_LINK
fi

BINDIR=$(dirname $THE_BASH_SOURCE)
BASEDIR=$(dirname $BINDIR)
SCRIPTSDIR="$BASEDIR/scripts"

if [ -f $SCRIPTSDIR/$1.sh ]; then
    $SCRIPTSDIR/$1.sh ${@:2}
elif [ -f $SCRIPTSDIR/$1-$2.sh ]; then
    $SCRIPTSDIR/$1-$2.sh ${@:3}
fi