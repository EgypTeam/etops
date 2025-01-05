#!/bin/bash

if [ "$1" == "" ]; then
    PROVIDER=minikube
else
    PROVIDER=$1
fi

STATUS=$(etops system status)
if [ "$STATUS" == "NOT INITIALIZED" ]; then
    etops system start-$PROVIDER
fi

case $STATUS in

    "NOT INITIALIZED" )
        etops system create ;;
    STOPPED )
        etops system start-$PROVIDER ;;
    *)
        echo Invalid state $STATUS. Please try again later ;;
esac