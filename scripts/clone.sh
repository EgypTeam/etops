#!/bin/bash

# etops clone REPO PRJ

REPO=$1
PRJ=$2

#git config core.sshCommand "ssh -vvv -i ~/.ssh/egt/$1/id_rsa -o IdentitiesOnly=yes -F /dev/null"

#git config core.sshCommand "ssh -i ~/.ssh/egt/$1/id_rsa -o IdentitiesOnly=yes -F /dev/null"

#git clone $2 --config core.sshCommand="ssh -i ~/.ssh/egt/$1/id_rsa -o IdentitiesOnly=yes -F /dev/null"

#echo $PRJ

ACTUALREPO=
ACTUALREPONAME=

if [[ "$REPO" =~ ^([^@]+)@([^:]+):([^/]+)/([^/]+)\.git$ ]]; then
    ACTUALREPO=$REPO
    ACTUALREPONAME=${BASH_REMATCH[4]}
else
    ACTUALREPO=git@bitbucket.org:egypteam/$REPO.git
    ACTUALREPONAME=$REPO
fi

if [[ "$PRJ" != "" ]]; then
    ACTUALPRJ=$PRJ
else
    ACTUALPRJ=egt
fi

git clone $ACTUALREPO --config core.sshCommand="ssh -i ~/.ssh/egt/$ACTUALPRJ/id_rsa -o IdentitiesOnly=yes -F /dev/null"

cd $ACTUALREPONAME

git config pull.rebase true
git config user.name "Pedro Ferreira"
git config user.email "pedro.ferreira@egypteam.com"

