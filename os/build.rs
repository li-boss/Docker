use std::fs::{self, File};
use std::io::{Result, Write};

const TARGET_PATH: &str = "../user/target/riscv64gc-unknown-none-elf/release";

fn main() -> Result<()> {
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rerun-if-changed=../user/src/bin");
    let mut apps = Vec::new();
    for entry in fs::read_dir("../user/src/bin")? {
        let path = entry?.path();
        if path.is_file() && path.extension().and_then(|s| s.to_str()) == Some("rs") {
            apps.push(path.file_stem().unwrap().to_str().unwrap().to_owned());
        }
    }
    apps.sort();
    assert!(!apps.is_empty() && apps.len() <= 16, "Expected 1..=16 user apps");
    let mut f = File::create("src/link_app.S")?;
    writeln!(f, ".section .data\n.align 3\n.global _num_app\n_num_app:\n    .quad {}", apps.len())?;
    for i in 0..apps.len() {
        writeln!(f, "    .quad app_{}_start", i)?;
    }
    writeln!(f, "    .quad app_{}_end", apps.len() - 1)?;
    for (i, app) in apps.iter().enumerate() {
        let bin = format!("{}/{}.bin", TARGET_PATH, app);
        let size = fs::metadata(&bin).unwrap_or_else(|e| panic!("{}: {}. Build user apps first!", bin, e)).len();
        assert!(size > 0 && size <= 0x20000, "Invalid application size: {}", app);
        println!("cargo:rerun-if-changed={}", bin);
        println!("cargo:warning=app_{}: {} ({} bytes)", i, app, size);
        writeln!(f, ".section .data\n.global app_{0}_start\n.global app_{0}_end\napp_{0}_start:\n    .incbin \"{1}\"\napp_{0}_end:", i, bin)?;
    }
    Ok(())
}
