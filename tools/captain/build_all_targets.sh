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

if [ -z $1 ]; then
    set -- "./captainrc"
fi

TARGETS=(libsndfile poppler libpng lua libxml2 sqlite3 libtiff openssl lua php)

set -x
VARIANTS=(afl_only symcc_afl)
VARIANTS+=(symcts symcts_afl)
VARIANTS+=(symcts_symqemu symcts_symqemu_afl)

FUZZERS=( "${VARIANTS[@]}" moptafl aflplusplus )

set -a
source "$1"
set +a

# build all targets for all fuzzers in a new tmux session with one per window each
tmux new-session -d -s build_all_targets
for fuzzer in "${FUZZERS[@]}"; do
    tmux new-window -t build_all_targets: -n "$fuzzer"
    tmux send-keys -t build_all_targets:"$fuzzer" "FUZZER=$fuzzer ./build_targets.sh $*" C-m
done

tmux at -t build_all_targets