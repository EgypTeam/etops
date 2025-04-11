#!/bin/bash

#minikube start --listen-address 0.0.0.0 --apiserver-names=satellite-silverstar --apiserver-ips=192.168.68.145 --mount-string="/c:/c" --mount

IPADDRESS=$(hostname -I | cut -f 1 -d" ")
ALLIPADDRESSES=$(hostname --ip-address | tr " " ",")

minikube start \
    --driver docker \
    --profile etops \
    --listen-address 0.0.0.0 \
    --mount-string="/c:/c" \
    --mount  \
    --apiserver-names=$HOSTNAME \
    --apiserver-ips=$IPADDRESS \
    --static-ip=192.168.49.2 \
    --extra-config=apiserver.service-node-port-range=1-65535

minikube addons enable ingress

# /etc/kubernetes/manifests/kube-apiserver.yaml
# --apiserver-service-node-port-range=1-65535


