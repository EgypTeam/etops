#!/bin/bash

PROJECT_NAME=$1

if [ -f "$1" ] || [ -d "" ]; then
  echo "File / Directory exists"
  exit 1
fi

ORIGINALDIR=$PWD

git clone git@github.com:NiloTemplates/nilo-java-web-war.git "$PROJECT_NAME"
rm -rf $PROJECT_NAME/.git
cd $PROJECT_NAME;


