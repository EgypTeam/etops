#!/bin/bash

if ! [ -d /c/development/devops/volumes/pingfederate-opt-out/instance ]; then
    echo "Creating Structure"
    sudo mkdir -p /c/development/devops/volumes/pingfederate-opt-out/
    sudo chmod -R 775 /c/development/devops/volumes/pingfederate-opt-out
    echo "Structure Created"
else 
    echo "Structure already exists. Setting permissions.."
    sudo chmod -R 775 /c/development/devops/volumes/pingfederate-opt-out
fi

kubectl create configmap pingfederate-config --from-file=/c/development/devops/lic/ping/pingfederate.lic --profile etops
