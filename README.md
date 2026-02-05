# LightAVRKernel
A light-weight RTOS for an 8-bit AVR SOC.  Using the Arduino Nano/Mega as development targets.  Currently a WIP.

## Inspiration and Resources
- TinyRealTime Kernel from Cornell: https://people.ece.cornell.edu/land/courses/ece4760/RTOS/TinyRealTime.pdf
- AVR bootloader tutorial: https://github.com/m3y54m/simple-avr-bootloader/tree/master
- AVR Acorn kernel: https://github.com/sergei-iliev/acorn-kernel
- QEMU AVR tutorial: https://www.qemu.org/docs/master/system/target-avr.html

## Development Environment
Initially, I will be using QEMU to emulate an AVR SOC and development board.  Specifically, I will be using the out-of-the-box `qemu-system-avr` binary using the `mega2560` machine.
