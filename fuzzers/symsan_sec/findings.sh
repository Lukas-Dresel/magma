#!/bin/bash

##
# Pre-requirements:
# - env SHARED: path to directory shared with host (to store results)
##

CRASH_DIR="$SHARED/findings/afl-master/crashes"

if [ ! -d "$CRASH_DIR" ]; then
    exit 1
fi

find "$SHARED/findings/afl-master/crashes" -type f -name 'id:*'
find "$SHARED/findings/afl-secondary/crashes" -type f -name 'id:*'
