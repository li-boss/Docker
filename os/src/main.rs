#![no_std]
#![no_main]

mod console;

use console::sys_exit;
use core::panic::PanicInfo;

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}

#[unsafe(no_mangle)]
extern "C" fn _start() {
    println!("Hello, world!");
    sys_exit(0);
}
