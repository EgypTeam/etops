#!/bin/bash
docker run --rm -v "$PWD":/dev/src -w /dev/src gcc:latest ./$*
