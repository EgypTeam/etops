#!/bin/bash

if [ "$1" == "system" ] | [ "$1" == "" ]; then
    etops system stop ${@:2}
else
    etops service stop $*
fi
