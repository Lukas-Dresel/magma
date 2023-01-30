#!/bin/bash
set -e

apt-get update && \
    apt-get install -y make build-essential clang llvm-dev git wget cmake subversion zip rsync \
        ninja-build python-pip zlib1g-dev rustc cargo inotify-tools protobuf-compiler libz3-dev

apt-get -y install libc++-dev libc++abi-dev

(
    pushd /tmp
    wget https://github.com/Z3Prover/z3/releases/download/z3-4.8.10/z3-4.8.10-x64-ubuntu-18.04.zip
    unzip z3-4.8.10-x64-ubuntu-18.04.zip
    rsync -r z3-4.8.10-x64-ubuntu-18.04/bin/libz3.so /usr/bin/
    rsync -r z3-4.8.10-x64-ubuntu-18.04/bin/libz3java.so /usr/bin/
    rsync -r z3-4.8.10-x64-ubuntu-18.04/bin/libz3.a /usr/bin/
    rsync -r z3-4.8.10-x64-ubuntu-18.04/bin/z3 /usr/bin/
    rsync -r z3-4.8.10-x64-ubuntu-18.04/include /usr/
)

rm -rf /usr/local/include/llvm && rm -rf /usr/local/include/llvm-c
rm -rf /usr/include/llvm && rm -rf /usr/include/llvm-c
ln -s /usr/lib/llvm-6.0/include/llvm /usr/include/llvm
ln -s /usr/lib/llvm-6.0/include/llvm-c /usr/include/llvm-c

