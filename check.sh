#!/bin/bash

echo "Source code formatting"
crystal tool format

echo "Shards check"
shards check

echo "Ameba code analysis"
./bin/ameba

crystal tool hierarchy -e Resource --no-color src/*-models.cr > docs/hierarchy
