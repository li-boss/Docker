const FD_STDOUT: usize = 1;

pub fn sys_write(fd: usize, buf: *const u8, len: usize) -> isize {
    match fd {
        FD_STDOUT => {
            let bytes = unsafe { core::slice::from_raw_parts(buf, len) };
            let text = core::str::from_utf8(bytes).unwrap();
            print!("{}", text);
            len as isize
        }
        _ => panic!("Unsupported fd in sys_write!"),
    }
}
