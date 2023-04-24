#!/bin/bash

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
# - env TARGET: path to target work dir
# - env OUT: path to directory where artifacts are stored
# - env SHARED: path to directory shared with host (to store results)
# - env PROGRAM: name of program to run (should be found in $OUT)
# - env ARGS: extra arguments to pass to the program
# - env FUZZARGS: extra arguments to pass to the fuzzer
##

. ~/.bashrc

# if nm "$OUT/afl/$PROGRAM" | grep -E '^[0-9a-f]+\s+[Ww]\s+main$'; then
#     ARGS="-"
# fi

mkdir -p "$SHARED/findings"

set -x

export ASAN_OPTIONS="$ASAN_OPTIONS:detect_leaks=0:abort_on_error=1:symbolize=0"

if [[ "$FUZZER" == *"afl"* ]]; then
    flag_cmplog=(-m none -c "$OUT/cmplog/$PROGRAM")

    export AFL_SKIP_CPUFREQ=1
    export AFL_NO_AFFINITY=1
    export AFL_NO_UI=1
    export AFL_MAP_SIZE=256000
    export AFL_DRIVER_DONT_DEFER=1
    export ASAN_OPTIONS="$ASAN_OPTIONS:detect_leaks=0:abort_on_error=1:symbolize=0"

    SYNC_FLAG_MASTER=()
    if [[ "$FUZZER" == *"symcts"* ]]; then
        SYNC_FLAG_MASTER=(-F "$SHARED/findings/symcts/corpus")
    fi

    "$FUZZER/afl/afl-fuzz" \
        -M afl-main \
        -i "$TARGET/corpus/$PROGRAM" \
        -o "$SHARED/findings" \
        "${SYNC_FLAG_MASTER[@]}" \
        $FUZZARGS -- "$OUT/afl/$PROGRAM" $ARGS 2>&1 &

    FUZZER_PID=$!

    # "$FUZZER/afl/afl-fuzz" \
    #     -S havoc \
    #     -i "$TARGET/corpus/$PROGRAM" \
    #     -o "$SHARED/findings" \
    #     "${flag_cmplog[@]}" -d \
    #     $FUZZARGS -- "$OUT/afl/$PROGRAM" $ARGS 2>&1 &
fi

if [[ "$FUZZER" == *"symcts"* ]]; then

    if [[ "$FUZZER" == *"symqemu"* ]]; then
        CONCOLIC_EXECUTION_MODE="symqemu"
    else
        CONCOLIC_EXECUTION_MODE="symcc"
    fi

    cd "$FUZZER/mctsse/implementation/libfuzzer_stb_image_symcts/fuzzer/" || exit 1
    RUST_BACKTRACE=1 RUST_LOG=INFO ./target/release/symcts \
        -n "symcts" \
        -i "$TARGET/corpus/$PROGRAM" \
        -s "$SHARED/findings/" \
        --afl-coverage-target "$OUT/afl-symcts/$PROGRAM" \
        --symcc-target "$OUT/symcts/$PROGRAM" \
        --vanilla-target "$OUT/vanilla/$PROGRAM" \
        --concolic-execution-mode "$CONCOLIC_EXECUTION_MODE" \
        --symqemu "$FUZZER/symqemu/build/x86_64-linux-user/symqemu-x86_64" \
        -- $ARGS 2>&1
else
    # this is the else so the custom drivers only start if it's not SyMCTS based
    if [[ "$FUZZER" == *"symcc"* || "$FUZZER" == *"symqemu"* ]]; then
        echo "Fuzzer main node has been started with PID $FUZZER_PID, waiting for it to come up"

        while ps -p $FUZZER_PID > /dev/null 2>&1 && \
            [[ ! -f "$SHARED/findings/afl-main/fuzzer_stats" ]]; do
            inotifywait -qq -t 1 -e create "$SHARED/findings" &> /dev/null
        done

        if [[ "$FUZZER" == *"symqemu"* ]]; then
            COMMAND=("$FUZZER/symqemu/build/x86_64-linux-user/symqemu-x86_64" "$OUT/vanilla/$PROGRAM")
            NAME=symqemu
        else
            COMMAND=("$OUT/symcts/$PROGRAM")
            NAME=symcc
        fi
        echo "Fuzzer should be up, let's see if it's still running, expecting to see fuzzer_stats"
        "$FUZZER/symcc/util/symcc_fuzzing_helper/target/release/symcc_fuzzing_helper" \
            -a afl-main -o "$SHARED/findings" -n "$NAME" \
            -- "${COMMAND[@]}" $ARGS 2>&1
    else
        wait
    fi
fi
