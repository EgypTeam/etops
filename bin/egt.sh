#!/bin/sh

if [ "$1" == "" ]; then
    echo "Missing command class"
    exit 1
fi

if [ "$2" == "" ]; then
    echo "Missing command"
    exit 1
fi

THE_BASH_SOURCE=$BASH_SOURCE
READ_LINK=$(readlink $THE_BASH_SOURCE)
if [ "$READ_LINK" != "" ]; then
    THE_BASH_SOURCE=$READ_LINK
fi

BINDIR=$(dirname $THE_BASH_SOURCE)
BASEDIR=$(dirname $BINDIR)
SCRIPTSDIR="$BASEDIR/scripts"
$SCRIPTSDIR/$1-$2.sh ${@:3}
