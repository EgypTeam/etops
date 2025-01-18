#!/bin/bash

if [ "$1" == "system" ] | [ "$1" == "" ]; then
    etops system destroy ${@:2}
else
    etops service destroy $*
fi
