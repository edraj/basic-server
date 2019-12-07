#!/bin/bash
crystal build  src/edraj.cr -o bin/edraj --error-trace && ./bin/edraj $@
