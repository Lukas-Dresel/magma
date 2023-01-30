#!/bin/bash

##
# Pre-requirements:
# - env SHARED: path to directory shared with host (to store results)
##

CRASH_DIRS=()
if [[ "$FUZZER" == *"afl"* ]]; then
    CRASH_DIRS+=("$SHARED/findings/afl-main/crashes")
fi
if [[ "$FUZZER" == *"symcts"* ]]; then
    CRASH_DIRS+=("$SHARED/findings/symcts/crashes")
fi
if [[ "$FUZZER" == *"symcc"* ]]; then
    CRASH_DIRS+=("$SHARED/findings/symcc/crashes")
fi


# DO THE FOLLOWING FOR EACH CRASH DIR

# if [ ! -d "${CRASH_DIRS[0]}" ]]; then
#     exit 1
# fi
# find ${CRASH_DIRS[0]} -type f -name 'id:*'

for CRASH_DIR in "${CRASH_DIRS[@]}"; do
    if [ ! -d "$CRASH_DIR" ]; then
        exit 1
    fi
    find "$CRASH_DIR" -type f -name 'id:*'
done