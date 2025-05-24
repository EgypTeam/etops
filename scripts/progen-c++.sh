#!/bin/bash

PROJECT_NAME=$1

if [ -f "$1" ] || [ -d "" ]; then
  echo "File / Directory exists"
  exit 1
fi

ORIGINALDIR=$PWD

git clone git@github.com:NiloTemplates/nilo-cpp.git "$PROJECT_NAME"
rm -rf $PROJECT_NAME/.git
cd $PROJECT_NAME;

sed -i -e "s/PROJECT_NAME := [^\n]*/PROJECT_NAME := $PROJECT_NAME/g" Makefile
sed -i -e "s/EXECUTABLE_NAME := [^\n]*/EXECUTABLE_NAME := $PROJECT_NAME/g" Makefile
