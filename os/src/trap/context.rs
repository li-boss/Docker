use riscv::register::sstatus::{self, Sstatus, SPP};

#[repr(C)]
pub struct TrapContext {
    pub x: [usize; 32],
    pub sstatus: Sstatus,
    pub sepc: usize,
}

impl TrapContext {
    pub fn set_sp(&mut self, sp: usize) { self.x[2] = sp; }
    pub fn app_init_context(entry: usize, sp: usize) -> Self {
        // riscv 0.10.1 exposes set_spp as a CSR function, not a Sstatus method.
        // Set it before reading the value saved in the new context.
        unsafe {
            sstatus::clear_sie();
            sstatus::set_spp(SPP::User);
        }
        let mut cx = Self { x: [0; 32], sstatus: sstatus::read(), sepc: entry };
        cx.set_sp(sp);
        cx
    }
}
