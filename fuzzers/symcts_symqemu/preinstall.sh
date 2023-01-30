#!/bin/bash
set -e

apt-get update && \
    apt-get install -y make build-essential git curl wget subversion \
        ninja-build python-pip zlib1g-dev inotify-tools

apt-get update && \
    apt-get install -y lsb-release wget software-properties-common gnupg

(
  pushd /tmp/
  wget https://apt.llvm.org/llvm.sh
  chmod +x llvm.sh
  sudo ./llvm.sh 12
  popd
)
# qemu dependencies (for SymQEMU)
apt-get install -y git libglib2.0-dev libfdt-dev libpixman-1-dev zlib1g-dev ninja-build libncurses-dev libcurl4-openssl-dev bison flex

# Installl CMake from Kitware apt repository
wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | \
    gpg --dearmor - | \
    tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null
echo 'deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ bionic main' | \
    tee /etc/apt/sources.list.d/kitware.list >/dev/null
apt-get update && \
    apt-get install -y cmake

pip install lit

update-alternatives \
  --install /usr/lib/llvm              llvm             /usr/lib/llvm-12  20 \
  --slave   /usr/bin/llvm-config       llvm-config      /usr/bin/llvm-config-12  \
    --slave   /usr/bin/llvm-ar           llvm-ar          /usr/bin/llvm-ar-12 \
    --slave   /usr/bin/llvm-as           llvm-as          /usr/bin/llvm-as-12 \
    --slave   /usr/bin/llvm-bcanalyzer   llvm-bcanalyzer  /usr/bin/llvm-bcanalyzer-12 \
    --slave   /usr/bin/llvm-c-test       llvm-c-test      /usr/bin/llvm-c-test-12 \
    --slave   /usr/bin/llvm-cov          llvm-cov         /usr/bin/llvm-cov-12 \
    --slave   /usr/bin/llvm-diff         llvm-diff        /usr/bin/llvm-diff-12 \
    --slave   /usr/bin/llvm-dis          llvm-dis         /usr/bin/llvm-dis-12 \
    --slave   /usr/bin/llvm-dwarfdump    llvm-dwarfdump   /usr/bin/llvm-dwarfdump-12 \
    --slave   /usr/bin/llvm-extract      llvm-extract     /usr/bin/llvm-extract-12 \
    --slave   /usr/bin/llvm-link         llvm-link        /usr/bin/llvm-link-12 \
    --slave   /usr/bin/llvm-mc           llvm-mc          /usr/bin/llvm-mc-12 \
    --slave   /usr/bin/llvm-nm           llvm-nm          /usr/bin/llvm-nm-12 \
    --slave   /usr/bin/llvm-objdump      llvm-objdump     /usr/bin/llvm-objdump-12 \
    --slave   /usr/bin/llvm-ranlib       llvm-ranlib      /usr/bin/llvm-ranlib-12 \
    --slave   /usr/bin/llvm-readobj      llvm-readobj     /usr/bin/llvm-readobj-12 \
    --slave   /usr/bin/llvm-rtdyld       llvm-rtdyld      /usr/bin/llvm-rtdyld-12 \
    --slave   /usr/bin/llvm-size         llvm-size        /usr/bin/llvm-size-12 \
    --slave   /usr/bin/llvm-stress       llvm-stress      /usr/bin/llvm-stress-12 \
    --slave   /usr/bin/llvm-symbolizer   llvm-symbolizer  /usr/bin/llvm-symbolizer-12 \
    --slave   /usr/bin/llvm-tblgen       llvm-tblgen      /usr/bin/llvm-tblgen-12

update-alternatives \
  --install /usr/bin/clang                 clang                  /usr/bin/clang-12     20 \
  --slave   /usr/bin/clang++               clang++                /usr/bin/clang++-12 \
  --slave   /usr/bin/clang-cpp             clang-cpp              /usr/bin/clang-cpp-12

# Uninstall old Rust
if which rustup; then rustup self uninstall -y; fi

# Install latest Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs > /tmp/rustup.sh && \
    sh /tmp/rustup.sh -y && \
    rm /tmp/rustup.sh

export PATH=$PATH:/root/.cargo/bin
echo PATH="$PATH:/root/.cargo/bin" >> ~/.bashrc
rustup default nightly-2022-09-18

pushd /tmp
wget https://apt.llvm.org/llvm.sh
chmod +x llvm.sh
sudo ./llvm.sh 12
popd

sudo -u magma git clone https://github.com/Lukas-Dresel/mctsse.git "$FUZZER/mctsse"
sudo -u magma mkdir -p "$FUZZER/mctsse/repos/"
sudo -u magma git clone -b feat/symcts https://github.com/Lukas-Dresel/LibAFL "$FUZZER/mctsse/repos/LibAFL"
sudo -u magma git clone --depth=1 https://github.com/Lukas-Dresel/z3jit "$FUZZER/mctsse/implementation/z3jit"
sudo -u magma git clone https://github.com/madler/zlib.git "$FUZZER/zlib"
sudo -u magma git clone -b z3-4.8.7 --depth 1 https://github.com/Z3Prover/z3.git "$FUZZER/z3"

if [[ "$FUZZER" != *"symqemu"* ]]; then
    sudo -u magma git clone -b llvmorg-12.0.0 --depth 1 https://github.com/llvm/llvm-project.git "$FUZZER/llvm"
fi
# build Z3
(
    cd "$FUZZER/z3"
    sudo -u magma mkdir -p build install cmake_conf
    cd build
    CXX=clang++ CC=clang sudo -u magma cmake ../ \
        -DCMAKE_INSTALL_PREFIX="/usr/"
        # -DCMAKE_INSTALL_Z3_CMAKE_PACKAGE_DIR="$FUZZER/z3/cmake_conf"
    sudo -u magma make -j $(nproc)
    make install
)

# build SyMCTS
if [[ "$FUZZER" == *"symcts"* ]]; then
    (
        export LLVM_CONFIG=/usr/lib/llvm-12/bin/llvm-config
        cd "$FUZZER/mctsse/implementation/libfuzzer_stb_image_symcts/runtime"
        sudo -u magma /bin/bash -c "cargo build --release -Zunstable-options --keep-going" || true
        cd "$FUZZER/mctsse/implementation/libfuzzer_stb_image_symcts/fuzzer"
        sudo -u magma /bin/bash -c "cargo build --release -Zunstable-options --features=sync_from_other_fuzzers --keep-going" || true
    )
fi