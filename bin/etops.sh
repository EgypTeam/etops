#!/bin/bash

THECOMMAND=$1
PONE=
PTWO=
PTWOREST=
PTHREEREST=

if [ "$THECOMMAND" == "" ]; then
    #echo "Missing command class"
    #exit 1
    THECOMMAND=ui
    PONE=ui
    PTWO=
    PTWOREST=
    PHREEREST=
else
    PONE=$1
    PTWO=$2
    PTWOREST=${@:2}
    PTHREEREST=${@:3}
fi

THE_BASH_SOURCE=$BASH_SOURCE
READ_LINK=$(readlink -f $THE_BASH_SOURCE)
ETOPS_COMMAND=$(basename $BASH_SOURCE)
ETOPS_COMMAND_ABSOLUTE_PATH=$(realpath $READ_LINK)
#echo $ETOPS_COMMAND
#echo $ETOPS_COMMAND_ABSOLUTE_PATH
if [ "$READ_LINK" != "" ]; then
    THE_BASH_SOURCE=$READ_LINK
fi

BINDIR=$(dirname $THE_BASH_SOURCE)
BASEDIR=$(dirname $BINDIR)
SCRIPTSDIR="$BASEDIR/scripts"

ALLPARMS=$@

if [ -f $SCRIPTSDIR/$PONE.sh ]; then
    set --
    source $SCRIPTSDIR/$PONE.sh $PTWOREST
    set -- $ALLPARMS
elif [ -f $SCRIPTSDIR/$PONE-$PTWO.sh ]; then
    set --
    source $SCRIPTSDIR/$PONE-$PTWO.sh $PTHREEREST
    set -- $ALLPARMS
fi