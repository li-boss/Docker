#![no_std]
#![no_main]

#[macro_use]
mod console;
mod lang_items;
mod sbi;
mod syscall;
mod trap;
mod batch;

use core::arch::global_asm;
global_asm!(include_str!("entry.asm"));
global_asm!(include_str!("link_app.S"));

fn clear_bss() {
    extern "C" {
        fn sbss();
        fn ebss();
    }
    let start = sbss as *const () as usize;
    let end = ebss as *const () as usize;
    for addr in start..end {
        unsafe { (addr as *mut u8).write_volatile(0); }
    }
}

#[no_mangle]
pub fn rust_main() -> ! {
    clear_bss();
    println!("[Kernel] Hello, world!");
    println!("[Kernel] Student ID: 24301037");
    trap::init();
    batch::init();
    batch::run_next_app();
}
