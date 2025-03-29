#!/bin/bash

for i in $(find . | grep -E ".sh\$"); do
    echo "===================="
    echo "FILE: $i"
    echo "===================="
    cat "$i"
    echo "===================="
    echo
done
