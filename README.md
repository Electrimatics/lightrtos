# LightAVRKernel
A light-weight RTOS for an 8-bit AVR SOC.  Using the Arduino Nano/Mega as development targets.  Currently a WIP.

## Inspiration and Resources
- TinyRealTime Kernel from Cornell: https://people.ece.cornell.edu/land/courses/ece4760/RTOS/TinyRealTime.pdf
- AVR bootloader tutorial: https://github.com/m3y54m/simple-avr-bootloader/tree/master
- AVR Acorn kernel: https://github.com/sergei-iliev/acorn-kernel
- QEMU AVR tutorial: https://www.qemu.org/docs/master/system/target-avr.html
- Rduino project: https://github.com/avr-rust/ruduino/tree/master

## Development Environment
Initially, I will be using QEMU to emulate an AVR SOC and development board.  Specifically, I will be using the out-of-the-box `qemu-system-avr` binary using the `mega2560` machine.

# Plan of Attack
## Phase 1: Research
I will research and collect scholarly sources (see above).  I am using TinyRealTime and FreeRTOS as the main inspirations for my kernel.

## Phase 2: Kernel Design
Using the sources I found above, I will plan the features I want my kernel to support.  For now:

1. Event-based
2. Preemptive
3. Infinite lifetime implemented via cyclic timing (see TinyRealTime)
4. Flat memory-space

Then, I plan to write hardware drivers for the specific target SOC (Arduino Nano/Mega):

1. USART
2. SPI
3. EEPROM
4. PWM channels

## Phase 3: Implementation
This is where the fun begins!  I plan to use emulation to develop my kernel at first, and then run it on real hardware.  I plan to debug my kernel by running it in QEMU and Renode.  I intend to use either C or Rust to implement it.  If time permits, I will attempt to run RobotOS on it (which already has a library for the Arduino IDE).

## Phase 4: Profiling
I also intend to use emulation to profile my kernel and verify execution.

## Phase 5: Writeup
This is where the not fun begins!  Here, I will document my design process and hurdles encountered in development.  I will provide a background on the hardware, existing sources, and the specific features my kernel implements.  I will also provide a memory footprint of the kernel and explain the resource constraints that led to design trade-offs.  Then, using emulation, I will provide execution metrics in a variety of applications.
