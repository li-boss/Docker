TARGET := riscv64gc-unknown-none-elf
MODE := release
APP_DIR := src/bin
TARGET_DIR := target/$(TARGET)/$(MODE)
APPS := $(wildcard $(APP_DIR)/*.rs)
ELFS := $(patsubst $(APP_DIR)/%.rs,$(TARGET_DIR)/%,$(APPS))
OBJCOPY := rust-objcopy --binary-architecture=riscv64

.PHONY: elf binary build
elf:
	@cargo build --release

binary: elf
	@set -e; for elf in $(ELFS); do $(OBJCOPY) "$$elf" --strip-all -O binary "$$elf.bin"; done

build: binary
