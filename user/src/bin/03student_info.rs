#![no_std]
#![no_main]

#[macro_use]
extern crate user_lib;

const STUDENT_ID: &str = "24301037";

#[no_mangle]
fn main() -> i32 {
    println!("Student ID: {}", STUDENT_ID);
    let digit_sum: u32 = STUDENT_ID.bytes()
        .map(|b| (b - b'0') as u32).sum();
    let mut sum = 0u32;
    for i in 1..=37 {
        sum += i;
    }
    println!("digit_sum = {}", digit_sum);
    println!("sum_1_to_37 = {}", sum);
    if digit_sum == 20 && sum == 703 {
        println!("Test student_info OK!");
        0
    } else {
        println!("Test student_info FAIL!");
        1
    }
}
