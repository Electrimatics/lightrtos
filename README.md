# LightRTOS
A light-weight RTOS for an 8-bit AVR SOC.  Using the Arduino Nano/Mega as development targets.  Currently a WIP.

## Inspiration and Resources
- TinyRealTime Kernel from Cornell: https://people.ece.cornell.edu/land/courses/ece4760/RTOS/TinyRealTime.pdf
- AVR bootloader tutorial: https://github.com/m3y54m/simple-avr-bootloader/tree/master
- AVR Acorn kernel: https://github.com/sergei-iliev/acorn-kernel
- QEMU AVR tutorial: https://www.qemu.org/docs/master/system/target-avr.html
- Rduino project: https://github.com/avr-rust/ruduino/tree/master

## Development Environment
We are utilizing QEMU v10.2.1 (pinned as a submodule) to setup an emulated development environment.  There is a helper script, `run-qemu.sh`, that will update the QEMU submodule, build and deploy QEMU from source in a container (docker or podman), named `lightrtos-qemu-runner`, and run QEMU with a provided binary file.  You will be prompted to select an image to run.  Use `./run-qemu.sh --help` to see all scrip options.

### Local Dependencies
- cargo
- git
- docker
- xhost (for X11 forwarding from the container)

