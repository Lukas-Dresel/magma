#!/bin/bash
set -e

apt-get update && \
    apt-get install -y make build-essential clang llvm-dev git wget cmake subversion zip rsync \
        ninja-build python-pip zlib1g-dev rustc cargo inotify-tools protobuf-compiler libz3-dev

apt-get -y install libc++-dev libc++abi-dev

(
    pushd /tmp
    git clone https://github.com/Z3Prover/z3.git
    cd z3
    git checkout z3-4.8.12
    mkdir -p build
    cd build
    cmake ..
    make -j
    make install
)

rm -rf /usr/local/include/llvm && rm -rf /usr/local/include/llvm-c
rm -rf /usr/include/llvm && rm -rf /usr/include/llvm-c
ln -s /usr/lib/llvm-6.0/include/llvm /usr/include/llvm
ln -s /usr/lib/llvm-6.0/include/llvm-c /usr/include/llvm-c

