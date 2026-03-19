/*!
 * Demonstration of writing to and reading from the serial console.
 */
#![no_std]
#![no_main]
#![feature(abi_avr_interrupt)]
#![feature(asm_experimental_arch)]

use core::cell::Cell;
// use core::arch::asm;
use panic_halt as _;

use arduino_hal::{
    pac::{
        TC1,
        tc1,
    },
    prelude::*,
};
use avr_device::interrupt::Mutex;

type Systick = u16;
type Priority = u8;

const GPR_FILE_SIZE: usize = 0x1f;
const MAX_TASKS: usize = 4;
const TC1_MODE: u8 = 4;
const MIN_TASK_STACK_SIZE: usize = 0x22;

// TODO: These are Atmega328p specific
//   source: avr/iom328p.h
const RAMSTART: usize = 0x100;
const RAMEND: usize = 0x8FF;
const SPR_OFFSET: usize = 0x20;
const SP: usize = SPR_OFFSET + 0x3E;

// ISR for TMR1 COMPAREA
// This is the main ticking mechanism in the kernel
#[avr_device::interrupt(atmega328p)]
fn TIMER1_COMPA() {
    avr_device::interrupt::free(|cs| {
        let systick_ref = SYSTICK.borrow(cs);
        systick_ref.set(systick_ref.get()+1);
    });
}

fn systick() -> Systick {
    avr_device::interrupt::free(|cs| {
        SYSTICK.borrow(cs).get()
    })
}

fn get_sp() -> usize {
    unsafe { *(SP as *const usize) }
}

fn set_sp(sp: usize) {
    unsafe { *(SP as *mut usize) = sp }
}

trait Task {
    fn run(&self);
    fn stop(&self);
    // fn yield(&self);
    // fn sleep(&self);
    // fn get_priority(&self) -> Priority;
    fn get_sp(&self) -> usize;
    fn set_base(&mut self, new_base: usize);
    fn get_base(&self) -> usize;
} 

// static mut RTOS_CORE: Mutex<Cell<LightRTOSCore>>;
static SYSTICK: Mutex<Cell<Systick>> = Mutex::new(Cell::new(0));

struct IdleTask {
    sp: usize,
    base: usize,
}

impl Task for IdleTask {
    fn run(&self) {
        loop {}
    }

    fn stop(&self) {
        loop {}
    }

    fn get_sp(&self) -> usize {
        self.sp
    }

    fn set_base(&mut self, new_base: usize) {
        self.base = new_base;
    }

    fn get_base(&self) -> usize {
        self.base
    }

}

// The lifetime of the each task must not exceed the lifetime of the kernel core
// TODO: Consider making the kernel core static
struct LightRTOSCore<'a> {
    tasks: [Option<&'a dyn Task>; MAX_TASKS],
    num_tasks: u8,
    running: u8, 
    base: usize,
}

impl<'a> LightRTOSCore<'a> {
    fn new() -> Self {
        let kernel_core = LightRTOSCore {
            tasks: [None; MAX_TASKS],
            num_tasks: 0,
            running: 0,
            base: get_sp(),
        };
        kernel_core
    }

    // TODO: I have to be very careful about 8/16 bit access to the stack here
    // I may need to be more explicit
    fn create_task(&mut self, task: &'a mut impl Task, size: usize) {
        // if size < MIN_TASK_STACK_SIZE {
        //     panic!();
        // }

        task.set_base(self.base);
        self.base -= size;

        // Save SREG on stack
        // Interrupt handler will push/restore at most SREG & r0-r31 from the stack
        unsafe { *(task.get_base() as *mut u16) = <dyn Task>::run as u16 };
        
        // Set stack to 0 for r0-r31
        for r in 0..31 {
            unsafe { *((task.get_base()-(r+2)) as *mut u8) = 0 };
        }

        self.tasks[self.num_tasks] = Some(task);
        self.num_tasks += 1;
    }

    fn start(tc1: TC1) {
        // Configure TIMER1 for the systick interval
        // The source clock is at 16MHz
        // Use CTC mode (4) to reset timer to BOTTOM 0x0 on OCR1A match
        tc1.tccr1a().write(|w| w.wgm1().set(TC1_MODE & 0b0011));
        tc1.tccr1b().write(|w| { w.cs1()
            .variant(tc1::tccr1b::CS1_A::PRESCALE_256)
            .wgm1()
            .set(TC1_MODE & 0b1100)
        });

        // Set TOP to 0xf424 with a prescaler of 256 for a one second period
        tc1.ocr1a().write(|w| w.set(0x100));

        // Enable interrupt for A compare
        tc1.timsk1().write(|w| w.ocie1a().set_bit());

        // Global enable interrupts
        unsafe { avr_device::interrupt::enable() };

        //TIMER1_COMPA();
    }
}

/*
 * Entrypoint and reset vector
 */
#[arduino_hal::entry]
fn main() -> ! {    
    let dp = arduino_hal::Peripherals::take().unwrap();
    let pins = arduino_hal::pins!(dp);
    let mut serial = arduino_hal::default_serial!(dp, pins, 57600);

    ufmt::uwriteln!(&mut serial, "Welcome to LightRTOS\r").unwrap_infallible();
    ufmt::uwriteln!(&mut serial, "Stack pointer: {}\r", get_sp()).unwrap_infallible();

    let mut core = LightRTOSCore::new();
    let mut idle_task = IdleTask {
        sp: 0,
        base: 0,
    };
    core.create_task(&mut idle_task, MIN_TASK_STACK_SIZE);

    LightRTOSCore::start(dp.TC1);
    // loop {
    //     // Read a byte from the serial connection
    //     let b = nb::block!(serial.read()).unwrap_infallible();

    //     // Answer
    //     ufmt::uwriteln!(&mut serial, "Got {} (SYSTICK={})!\r", b, systick()).unwrap_infallible();
    // }

    // Ideally, the "start" function should not return
    loop {}
    panic!()
}
