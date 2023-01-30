#!/bin/bash

set -e
# set -x

VARIANTS=(afl_companion symcc_afl symqemu_afl)
VARIANTS+=(symcts symcts_afl)
VARIANTS+=(symcts_symqemu symcts_symqemu_afl)
VARIANTS+=(symcts_context_sensitive symcts_decision_coverage)

FILES=(build.sh fetch.sh findings.sh instrument.sh preinstall.sh run.sh runonce.sh src/afl_driver.cpp)

for VARIANT in "${VARIANTS[@]}"; do
    echo "Creating variant $VARIANT"
    rm -rf "$VARIANT"
    mkdir -p "$VARIANT/src"
    for f in "${FILES[@]}"; do
        ln "BASE_symcts/$f" "$VARIANT/$f"
    done
done