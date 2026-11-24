#![no_std]
#![no_main]

use core::arch::asm;
#[macro_use]
extern crate user_lib;

#[no_mangle]
fn main() -> i32 {
    println!("Into Test store_fault, we will insert an invalid store operation...");
    println!("Kernel should kill this application!");
    // Deliberately issue a hardware store to address zero.
    unsafe { asm!("sb zero, 0(zero)", options(nostack)); }
    0
}
