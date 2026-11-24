use core::arch::asm;
use core::cell::{RefCell, UnsafeCell};
use crate::trap::TrapContext;
use lazy_static::lazy_static;

const MAX_APP_NUM: usize = 16;
const APP_BASE_ADDRESS: usize = 0x80400000;
const APP_SIZE_LIMIT: usize = 0x20000;
const USER_STACK_SIZE: usize = 4096 * 2;
const KERNEL_STACK_SIZE: usize = 4096 * 2;

#[repr(align(4096))]
struct KernelStack { data: UnsafeCell<[u8; KERNEL_STACK_SIZE]> }
#[repr(align(4096))]
struct UserStack { data: UnsafeCell<[u8; USER_STACK_SIZE]> }
// This teaching kernel is single-hart and does not enable nested interrupts.
unsafe impl Sync for KernelStack {}
unsafe impl Sync for UserStack {}
static KERNEL_STACK: KernelStack = KernelStack { data: UnsafeCell::new([0; KERNEL_STACK_SIZE]) };
static USER_STACK: UserStack = UserStack { data: UnsafeCell::new([0; USER_STACK_SIZE]) };

impl KernelStack {
    fn get_sp(&self) -> usize { self.data.get() as usize + KERNEL_STACK_SIZE }
    fn push_context(&self, cx: TrapContext) -> *mut TrapContext {
        let ptr = (self.get_sp() - core::mem::size_of::<TrapContext>()) as *mut TrapContext;
        unsafe { ptr.write(cx); }
        ptr
    }
}
impl UserStack {
    fn get_sp(&self) -> usize { self.data.get() as usize + USER_STACK_SIZE }
}

struct AppManager { inner: RefCell<AppManagerInner> }
struct AppManagerInner {
    num_app: usize,
    current_app: usize,
    app_start: [usize; MAX_APP_NUM + 1],
}
// Only accessed serially on the one QEMU hart used in this experiment.
unsafe impl Sync for AppManager {}

impl AppManagerInner {
    fn print_app_info(&self) {
        println!("[kernel] num_app = {}", self.num_app);
        for i in 0..self.num_app {
            println!("[kernel] app_{} [{:#x}, {:#x})", i, self.app_start[i], self.app_start[i + 1]);
        }
    }
    unsafe fn load_app(&self, app_id: usize) {
        if app_id >= self.num_app {
            panic!("All applications completed!");
        }
        let start = self.app_start[app_id];
        let end = self.app_start[app_id + 1];
        assert!(end >= start && end - start <= APP_SIZE_LIMIT, "Application exceeds load area");
        assert!(end <= APP_BASE_ADDRESS, "Embedded application overlaps load area");
        println!("[kernel] Loading app_{}", app_id);
        for addr in APP_BASE_ADDRESS..APP_BASE_ADDRESS + APP_SIZE_LIMIT {
            (addr as *mut u8).write_volatile(0);
        }
        let src = core::slice::from_raw_parts(start as *const u8, end - start);
        let dst = core::slice::from_raw_parts_mut(APP_BASE_ADDRESS as *mut u8, src.len());
        dst.copy_from_slice(src);
        asm!("fence.i");
    }
}

lazy_static! {
    static ref APP_MANAGER: AppManager = {
        extern "C" { fn _num_app(); }
        let ptr = _num_app as *const () as *const usize;
        let num_app = unsafe { ptr.read_volatile() };
        assert!(num_app > 0 && num_app <= MAX_APP_NUM, "Invalid application count");
        let mut app_start = [0usize; MAX_APP_NUM + 1];
        let raw = unsafe { core::slice::from_raw_parts(ptr.add(1), num_app + 1) };
        app_start[..=num_app].copy_from_slice(raw);
        AppManager { inner: RefCell::new(AppManagerInner { num_app, current_app: 0, app_start }) }
    };
}

pub fn init() {
    extern "C" { fn ekernel(); }
    assert!((ekernel as *const () as usize) <= APP_BASE_ADDRESS, "Kernel overlaps application area");
    assert_eq!(core::mem::size_of::<TrapContext>(), 34 * 8);
    println!("[kernel] TrapContext size = {} bytes", core::mem::size_of::<TrapContext>());
    println!("[kernel] user_sp = {:#x}, kernel_sp = {:#x}", USER_STACK.get_sp(), KERNEL_STACK.get_sp());
    APP_MANAGER.inner.borrow().print_app_info();
}

pub fn run_next_app() -> ! {
    {
        let mut manager = APP_MANAGER.inner.borrow_mut();
        let app_id = manager.current_app;
        unsafe { manager.load_app(app_id); }
        manager.current_app += 1;
    }
    let cx = TrapContext::app_init_context(APP_BASE_ADDRESS, USER_STACK.get_sp());
    let cx_addr = KERNEL_STACK.push_context(cx) as usize;
    extern "C" { fn __restore(cx_addr: usize) -> !; }
    unsafe { __restore(cx_addr); }
}
