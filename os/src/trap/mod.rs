mod context;
pub use context::TrapContext;

use core::arch::global_asm;
use riscv::register::{
    stvec::{self, TrapMode},
    scause::{self, Trap, Exception},
    stval,
};
use crate::{batch::run_next_app, syscall::syscall};
global_asm!(include_str!("trap.S"));

pub fn init() {
    extern "C" { fn __alltraps(); }
    unsafe { stvec::write(__alltraps as *const () as usize, TrapMode::Direct); }
}

#[no_mangle]
pub extern "C" fn trap_handler(cx: &mut TrapContext) -> &mut TrapContext {
    let cause = scause::read().cause();
    let value = stval::read();
    match cause {
        Trap::Exception(Exception::UserEnvCall) => {
            cx.sepc += 4;
            cx.x[10] = syscall(cx.x[17], [cx.x[10], cx.x[11], cx.x[12]]) as usize;
        }
        Trap::Exception(Exception::StoreFault) |
        Trap::Exception(Exception::StorePageFault) => {
            println!("[kernel] {:?}: stval={:#x}, sepc={:#x}", cause, value, cx.sepc);
            println!("[kernel] PageFault in application, core dumped.");
            run_next_app();
        }
        Trap::Exception(Exception::IllegalInstruction) => {
            println!("[kernel] {:?}: stval={:#x}, sepc={:#x}", cause, value, cx.sepc);
            println!("[kernel] IllegalInstruction in application, core dumped.");
            run_next_app();
        }
        _ => panic!("Unsupported trap {:?}, stval = {:#x}, sepc = {:#x}!", cause, value, cx.sepc),
    }
    cx
}
