#!/bin/bash -e

##
# Pre-requirements:
# - env FUZZER: fuzzer name (from fuzzers/)
# - env TARGET: target name (from targets/)
# + env MAGMA: path to magma root (default: ../../)
# + env ISAN: if set, build the benchmark with ISAN/fatal canaries (default:
#       unset)
# + env HARDEN: if set, build the benchmark with hardened canaries (default:
#       unset)
##
set -x

if [ -z $FUZZER ]; then
    echo '$FUZZER must be specified as an environment variable.'
    exit 1
fi
if [ -z $1 ]; then
    set -- "./captainrc"
fi

TARGETS=(libsndfile poppler libpng lua libxml2 sqlite3 libtiff openssl lua php)
set -a
source "$1"
set +a

RESULTS=""
for tgt in "${TARGETS[@]}"; do
    TARGET="$tgt" ./build.sh "$@"
    RESULT=$?
    echo "result=$?"
    RESULTS="$RESULTS $tgt=$RESULT"
done
echo "RESULTS: $RESULTS"