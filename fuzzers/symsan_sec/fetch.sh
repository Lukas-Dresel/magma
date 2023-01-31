#!/bin/bash
set -e

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
##

git clone --no-checkout https://github.com/google/AFL.git "$FUZZER/afl"
git -C "$FUZZER/afl" checkout 82b5e359463238d790cadbe2dd494d6a4928bff3
cp "$FUZZER/src/afl_driver.cpp" "$FUZZER/afl/afl_driver.cpp"

git clone https://github.com/r-fuzz/fastgen.git "$FUZZER/symsan"
git clone https://github.com/Lukas-Dresel/symcc_libc_preload.git "$FUZZER/symcc_libc_preload"
git clone https://github.com/madler/zlib.git "$FUZZER/zlib"

(
    pushd "$FUZZER/symsan"
    git checkout 2937d1c029abeab1b0de70705c393e8485617266
    popd
)
cd "$FUZZER/symsan" && patch -p1 < $FUZZER/sec.patch
cat "$FUZZER/abilist_extra.txt" >> "$FUZZER/symsan/llvm_mode/dfsan_rt/dfsan/done_abilist.txt"
#git clone --no-checkout https://github.com/Z3Prover/z3.git "$FUZZER/z3"
#git -C "$FUZZER/z3" checkout z3-4.8.12

#git clone --depth 1 -b release/11.x \
#    https://github.com/llvm/llvm-project.git "$FUZZER/llvm"
