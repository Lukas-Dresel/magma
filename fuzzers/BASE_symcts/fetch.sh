#!/bin/bash
set -e

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
##

RERUN=76

# sudo chown -R magma:magma "$FUZZER/z3"
# sudo chown -R magma:magma "$FUZZER/llvm"
# sudo chown -R magma:magma "$FUZZER/zlib"
git clone https://github.com/Lukas-Dresel/zlib-nop.git "$FUZZER/zlib-nop"

(
    cd "$FUZZER/mctsse"
    git pull --rebase
    cd "$FUZZER/mctsse/repos/LibAFL"
    git pull --rebase
    cd "$FUZZER/mctsse/implementation/z3jit"
    git pull --rebase
)

git clone https://github.com/Lukas-Dresel/symcc_libc_preload.git "$FUZZER/mctsse/repos/symcc_libc_preload"

git clone https://github.com/AFLPlusPlus/AFLPlusPlus.git "$FUZZER/afl"

git clone -b feat/larger_counters https://github.com/Lukas-Dresel/AFLPlusPlus.git "$FUZZER/afl-symcts"

# if [[ "$FUZZER" == *"symcts"* ]]; then
git clone --depth=1 https://github.com/Lukas-Dresel/symcc "$FUZZER/symcc"
# fi
git -C "$FUZZER/symcc" submodule init
git -C "$FUZZER/symcc" submodule update

if [[ "$FUZZER" == *"symqemu"* ]]; then
    if [[ "$FUZZER" == *"symcts"* ]]; then
        git clone --depth=1 https://github.com/Lukas-Dresel/symqemu "$FUZZER/symqemu"
    else
        git clone --depth=1 https://github.com/eurecom-s3/symqemu "$FUZZER/symqemu"
    fi
fi
if [[ "$FUZZR" == *"symsan"* ]]; then
    # git clone --depth=1 https://github.com/R-Fuzz/symsan "$FUZZER/symsan"
    git clone --depth=1 https://github.com/R-Fuzz/fastgen "$FUZZER/symsan"
fi
