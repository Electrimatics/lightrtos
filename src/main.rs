/*!
 * Demonstration of writing to and reading from the serial console.
 */
#![no_std]
#![no_main]
#![feature(abi_avr_interrupt)]

use core::cell::Cell;
use panic_halt as _;

use arduino_hal::{
    pac::tc1,
    prelude::*,
};
use avr_device::interrupt::Mutex;

static SYSTICK: Mutex<Cell<u16>> = Mutex::new(Cell::new(0));

#[avr_device::interrupt(atmega328p)]
fn TIMER1_COMPA() {
    avr_device::interrupt::free(|cs| {
        let systick_ref = SYSTICK.borrow(cs);
        systick_ref.set(systick_ref.get()+1);
    })
    // ufmt::uwriteln!(&mut serial, "Timer tick: {}\r", SYSTICK);
}

/*
 * Entrypoint function, must only have one defined.
 * Placed at addr. 0x0
 */
#[arduino_hal::entry]
fn main() -> ! {
    let dp = arduino_hal::Peripherals::take().unwrap();
    let pins = arduino_hal::pins!(dp);
    let mut serial = arduino_hal::default_serial!(dp, pins, 57600);

    ufmt::uwriteln!(&mut serial, "Hello from Arduino!\r").unwrap_infallible();

    let mut systick: u16 = 0;

    // Configure TIMER1 for the systick interval
    let tc1 = dp.TC1;

    // Set WGM1 to normal mode (TOP=0xFFFF)
    tc1.tccr1a().write(|w| w.wgm1().set(0b00));

    // Set prescaler and then waveform generation to PWM, phase correct, 8-bit
    tc1.tccr1b().write(|w| { w.cs1()
        .variant(tc1::tccr1b::CS1_A::PRESCALE_1024)
        .wgm1()
        .set(0b01)
    });

    // Set compare value
    tc1.ocr1a().write(|w| w.set(100));

    // Enable interrupt for A compare
    tc1.timsk1().write(|w| w.ocie1a().set_bit());

    unsafe { avr_device::interrupt::enable() };

    loop {
        
        // Get the current value of the systick
        avr_device::interrupt::free(|cs| {
            systick = SYSTICK.borrow(cs).get();
        });
        // Read a byte from the serial connection
        let b = nb::block!(serial.read()).unwrap_infallible();

        // Answer
        ufmt::uwriteln!(&mut serial, "Got {} (SYSTICK={})!\r", b, systick).unwrap_infallible();
    }
}
