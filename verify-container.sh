#!/usr/bin/env bash
set -Eeuo pipefail
source /root/.cargo/env
cd /mnt
test "$(cat rust-toolchain)" = nightly-2026-05-08
rustup show active-toolchain | grep '^nightly-2026-05-08'
rustc --version
cargo --version
rustup target list --installed | grep -Fx riscv64gc-unknown-none-elf
rustup component list --installed | grep '^llvm-tools'
rustup component list --installed | grep '^rust-src'
test -d "$(rustc --print sysroot)/lib/rustlib/src/rust/library"
printf '#![no_std]\npub fn environment_check() -> usize { 42 }\n' | \
  rustc --crate-name gardeneros_environment_check --crate-type lib \
    --target riscv64gc-unknown-none-elf --emit=obj -o /tmp/gardeneros-environment-check.o -
cargo objdump --version
qemu-system-riscv64 --version | head -n 1 | grep 'version 11.0.0'
qemu-riscv64 --version | head -n 1 | grep 'version 11.0.0'
printf '\nGardenerOS environment verification passed.\n'
