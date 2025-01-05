#!/bin/bash

#minikube start --listen-address 0.0.0.0 --apiserver-names=satellite-silverstar --apiserver-ips=192.168.68.145 --mount-string="/c:/c" --mount

IPADDRESS=$(hostname -I | cut -f 1 -d" ")
ALLIPADDRESSES=$(hostname --ip-address | tr " " ",")

minikube delete --profile etops
