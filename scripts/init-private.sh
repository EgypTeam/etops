#!/bin/bash

rm -rf descriptors haproxy etops-confscripts-after-delete confscripts-before-create

git submodule add git@github.com:EgypTeam/etops-descriptors.git descriptors
git submodule add git@github.com:EgypTeam/etops-haproxy.git haproxy
git submodule add git@github.com:EgypTeam/etops-confscripts-after-delete.git confscripts-after-delete
git submodule add git@github.com:EgypTeam/etops-confscripts-before-create.git confscripts-before-create
