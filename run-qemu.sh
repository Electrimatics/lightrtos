#!/bin/bash
CONTAINER_IMAGE="lightrtos-qemu-runner:latest"

usage() {
    echo "$0 <-d|--debug> <-t|--telnet>"
    echo "  -d|--debug: Auto-start GDB and connect to the emulator"
    echo "  -t|--telnet: Auto-start telnet and connect to the emulator (USART interface)"
}

cleanup() {
    if [ ! -z $TELNET_PID ]; then
        kill $TELNET_PID
    fi

    if [ ! -z $GDB_PID ]; then
        kill $GDB_PID
    fi
}
trap cleanup "EXIT"

# Parse args
START_DEBUG=0
START_TELNET=0
QEMU_RUN_ARGS=""
# Parse options
while [ $# -gt 0 ]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -d|--debug)
            START_DEBUG=1
            QEMU_RUN_ARGS+="-gdb tcp::10001 -S"
            shift
            ;;
        -t|--telnet)
            START_TELNET=1
            shift
            ;;
        *)
            echo "Unknown option -- $0"
            shift
            ;;
    esac
done

# Check if docker image is already built
echo "Checking for existing image with QEMU"
if [ -z $(docker images -q $CONTAINER_IMAGE 2>/dev/null) ]; then
    echo "No image found. Building."

    git submodule update --init
    (cd qemu && git submodule update --init)
    docker build --rm -f Dockerfile-qemu --tag $CONTAINER_IMAGE .
fi

# TODO: Make this a script arg?
# Enumerate firmware images
firmware_dir="./firmware"
images=($(ls $firmware_dir))
num_images=${#images[@]}
min_valid_selection=1
max_valid_selection=$(($num_images+1))

# Prompt for image selection
echo "Select a firmware image from directory $firmware_dir:"
PS3="[$min_valid_selection-$max_valid_selection] > "
select opt in "${images[@]}" "Quit"; do
    case "$REPLY" in
    # Quit case
    $(($num_images+1)))
        echo "Exiting"
        exit 0
        ;;

    # Any other input - we provide additional validation afterwards
    *)
        if [[ $REPLY -lt $min_valid_selection || $REPLY -gt $max_valid_selection ]]; then
            echo "Invalid selection -- valid range: [$min_valid_selection-$max_valid_selection]"
            continue
        fi
        break
        ;;
    esac
done

# Double check a firmware image was elected (ie: sending EOF will close the above prompt w/o selecting an image)
firmware_image_abs=$(readlink -f $firmware_dir/${images[$(($REPLY-1))]})
if [[ -z $REPLY || -z $firmware_image_abs ]]; then
    echo "No firmware image selected. Exiting"
    exit 1
fi

echo "Select firmware image $REPLY: $firmware_image_abs"

# TODO: Figure out a better way to debug and connect with telnet
# We are heavily relying on sleeping 3 and 5 seconds to make things work
# Telnet must be connected in before GDB
TELNET_PID=0
if [ $START_TELNET -ne 0 ]; then
    lxterminal --title "QEMU USART" -e "source utils.sh; wait_for_port 10000; sleep 3; \
        telnet localhost 10000;" &
    TELNET_PID=$!
fi

GDB_PID=0
if [ $START_DEBUG -ne 0 ]; then
    # TODO: Add ability to pass GDB file in
    lxterminal --title "QEMU DEBUG" -e "source utils.sh; wait_for_port 10001; sleep 5; \
        gdb -iex 'set remotetimeout unlimited' \
        -iex 'set architecture avr' \
        -iex 'symbol-file $firmware_image_abs' \
        -iex 'target remote localhost:10001'" &
    GDB_PID=$!
fi

echo "Running container $CONTAINER_IMAGE with args $QEMU_RUN_ARGS"
docker run --rm -it -p 10000-10001:10000-10001 -v $firmware_image_abs:/firmware.img $CONTAINER_IMAGE $QEMU_RUN_ARGS