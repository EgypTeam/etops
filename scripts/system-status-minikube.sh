#!/bin/bash

#minikube start --listen-address 0.0.0.0 --apiserver-names=satellite-silverstar --apiserver-ips=192.168.68.145 --mount-string="/c:/c" --mount

IPADDRESS=$(hostname -I | cut -f 1 -d" ")
ALLIPADDRESSES=$(hostname --ip-address | tr " " ",")

#minikube start --listen-address 0.0.0.0 --mount-string="/c:/c" --mount  --apiserver-names=$HOSTNAME --apiserver-ips=$IPADDRESS

OUTPUT=$(minikube status --profile etops 2> /dev/null)

echo $OUTPUT

NOTFOUND=$(echo $OUTPUT | grep -i "Profile \"etops\" not found.")
STARTING=$(echo $OUTPUT | grep -i "The \"etops\" host does not exist!")
RUNNING=$(echo $OUTPUT | grep -i "host: Running")
STOPPED=$(echo $OUTPUT | grep -i "host: Stopped")
#echo $STOPPING
if [ "$NOTFOUND" != "" ]; then
    echo "NOT INITIALIZED"
elif [ "$STARTING" != "" ]; then
    echo "STARTING..."
elif [ "$STARTING2" != "" ]; then
    echo "STARTING..."
elif [ "$STOPPED" != "" ]; then
    echo "STOPPED"
elif [ "$RUNNING" != "" ]; then
    echo "RUNNING"
else
    echo "PROCESSING..."
fi
