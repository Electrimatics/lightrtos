#!/bin/bash
# START_TELNET, START_DEBUG, QEMU_RUN_ARGS populated by docker run command (using -e flag)

if [ $START_TELNET -ne 0 ]; then
    lxterminal --title "QEMU USART" -e "until kill -0 $(pidof qemu-system-avr); do : ; done; sleep 1; telnet localhost 10000;" &
fi

if [ $START_DEBUG -ne 0 ]; then
    # TODO: Add ability to pass GDB file in
    QEMU_RUN_ARGS+="--gdb tcp::10001 -S"
    lxterminal --title "QEMU DEBUG" -e "until nc -z localhost 10001; do sleep 0.1; done; \
        gdb-multiarch -iex 'set remotetimeout unlimited' \
        -iex 'set architecture avr' \
        -iex 'symbol-file /firmware.img' \
        -iex 'target remote :10001'" &
fi

# TODO: Need to manually continue to have input accepted on USART over telnet
QEMU_RUN_ARGS="-nographic -monitor stdio -machine arduino-uno -serial tcp::10000,server,wait=on -bios /firmware.img $QEMU_RUN_ARGS"
echo "Running QEMU with args: $QEMU_RUN_ARGS"
qemu-system-avr $QEMU_RUN_ARGS