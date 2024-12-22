#!/bin/bash

if [ "$1" == "" ]; then
    PROVIDER=minikube
else
    PROVIDER=$1
fi

egt dev start-$PROVIDER
