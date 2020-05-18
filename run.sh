#!/bin/bash
#crystal build  src/edraj.cr -o bin/edraj --error-trace && ./bin/edraj $@
export CRYSTAL_LOG_LEVEL="DEBUG"
export CRYSTAL_LOG_SOURCES="*"
./bin/sentry
