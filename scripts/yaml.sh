#!/bin/bash

if [ "$1" == "system" ] | [ "$1" == "" ]; then
    echo -n ""
else
    etops service yaml $*
fi
