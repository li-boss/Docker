#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "Setup failed at line $LINENO" >&2' ERR
[[ $(id -u) == 0 ]] || { echo 'Run as container root.' >&2; exit 1; }
cd /root
python3 /mnt/configure-repos.py
dnf_options=(-y --setopt=max_parallel_downloads=8 --setopt=retries=6 --setopt=timeout=60 --disablerepo=debuginfo,source,update-source)
dnf "${dnf_options[@]}" groupinstall 'Development Tools'
dnf "${dnf_options[@]}" install ca-certificates curl vim git gcc gcc-c++ autoconf automake kernel-devel \
  libmpc-devel mpfr-devel gmp-devel glib2 glib2-devel make cmake gawk bison flex \
  texinfo gperf libtool patchutils bc python3 python3-pip ninja-build wget xz \
  python3-tomli python3-sphinx pkgconf-pkg-config zlib-devel

export RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static
export RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup
if ! grep -q '^# GardenerOS Rust environment$' /root/.bashrc; then
  cat >> /root/.bashrc <<'BASHRC'

# GardenerOS Rust environment
export RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static
export RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup
[ ! -f /root/.cargo/env ] || . /root/.cargo/env
BASHRC
fi
if [[ ! -x /root/.cargo/bin/rustup ]]; then
  curl --fail --location --retry 3 https://sh.rustup.rs -o /tmp/gardener-rustup.sh
  sh /tmp/gardener-rustup.sh -y --profile minimal --default-toolchain none
fi
source /root/.cargo/env
mkdir -p /root/.cargo
if [[ -f /root/.cargo/config.toml ]] && ! cmp -s /mnt/config/cargo-config.toml /root/.cargo/config.toml; then
  cp -p /root/.cargo/config.toml "/root/.cargo/config.toml.backup-$(date +%Y%m%d%H%M%S)"
fi
cp /mnt/config/cargo-config.toml /root/.cargo/config.toml
rustup toolchain install nightly --profile minimal
rustup default nightly
rustup toolchain install nightly-2026-05-08 --profile minimal
rustup target add --toolchain nightly-2026-05-08 riscv64gc-unknown-none-elf
rustup component add --toolchain nightly-2026-05-08 llvm-tools-preview rust-src
cargo +nightly-2026-05-08 install cargo-binutils --locked

if ! command -v qemu-system-riscv64 >/dev/null || ! qemu-system-riscv64 --version | head -n 1 | grep -q 'version 11.0.0'; then
  mkdir -p /root/src
  cd /root/src
  if [[ ! -f qemu-11.0.0.tar.xz && -f /mnt/.downloads/qemu-11.0.0.tar.xz ]]; then
    cp /mnt/.downloads/qemu-11.0.0.tar.xz .
  fi
  if [[ ! -f qemu-11.0.0.tar.xz ]]; then
    curl --fail --location --retry 3 https://download.qemu.org/qemu-11.0.0.tar.xz -o qemu-11.0.0.tar.xz.part
    mv qemu-11.0.0.tar.xz.part qemu-11.0.0.tar.xz
  fi
  [[ -d qemu-11.0.0 ]] || tar xJf qemu-11.0.0.tar.xz
  cd qemu-11.0.0
  ./configure --target-list=riscv64-softmmu,riscv64-linux-user
  make -j"${BUILD_JOBS:-$(nproc)}"
  make install
fi
bash /mnt/verify-container.sh
