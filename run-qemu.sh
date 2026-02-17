#!/bin/bash
CONTAINER_MANAGER="${CONTAINER_MANAGER:-docker}"
CONTAINER_IMAGE="lightrtos-qemu-runner:latest"
HOST_DEPENDENCIES=("git" "xhost" "$CONTAINER_MANAGER")

usage() {
    echo "$0 <-h|--help> <--build-container> <--no-telnet> <--no-debug>"
    echo "  -h|--help: Shows this help message."
    echo "  --build-container: Force build a new container."
    echo "  --no-telnet: Do not auto-start telnet inside the container connected to USART. Will be available on port 10000."
    echo "  --no-debug: Do not auto-start gdb-multiarch inside the container. Will be available on port 10001."
    echo ""
    echo " Environment variables:"
    echo "  CONTAINER_MANAGER: Set container manager (docker or podman recommended). Default: docker"
}

cleanup() {
    :
}
trap cleanup "EXIT"

# Validate host dependencies
MISSING_DEPENDENCIES=0
for dependency in ${HOST_DEPENDENCIES[@]}; do
    which $dependency 1>/dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "Missing host dependency: $dependency"
        MISSING_DEPENDENCIES=1
    fi
done

if [ $MISSING_DEPENDENCIES -ne 0 ]; then
    exit 1
fi

BUILD_CONTAINER=0
START_TELNET=1
START_DEBUG=1

DOCKER_RUN_ARGS=""
QEMU_RUN_ARGS=""

# Parse options
while [ $# -gt 0 ]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        --build-container)
            BUILD_CONTAINER=1
            shift
            ;;
        --no-telnet)
            START_TELNET=0
            shift
            ;;
        --no-debug)
            START_DEBUG=0
            shift
            ;;
        *)
            echo "$0 Unknown option -- $1"
            shift
            ;;
    esac
done

# Check if image is already built (or force build specified)
if [[ -z $($CONTAINER_MANAGER images -q $CONTAINER_IMAGE 2>/dev/null) || $BUILD_CONTAINER -ne 0 ]]; then
    echo "Building container image: $CONTAINER_IMAGE"

    git submodule update --init
    (cd qemu && git submodule update --init)
    # $CONTAINER_MANAGER image rmi $CONTAINER_IMAGE 2>/dev/null
    $CONTAINER_MANAGER build --rm -f Dockerfile-qemu --tag $CONTAINER_IMAGE .
fi

# TODO: Make this a script arg?
FIRMWARE_DIR="./firmware"
FIRMWARE_IMAGES=($(ls $FIRMWARE_DIR))
NUM_FIRMWARE_IMAGES=${#FIRMWARE_IMAGES[@]}
MIN_VALID_SELECTION=1
MAX_VALID_SELECTION=$(($NUM_FIRMWARE_IMAGES+1))

# Prompt for image selection
echo "Select a firmware image from directory $FIRMWARE_DIR:"
PS3="[$MIN_VALID_SELECTION-$MAX_VALID_SELECTION] > "
select opt in "${FIRMWARE_IMAGES[@]}" "Quit"; do
    case "$REPLY" in
    # Quit case
    $(($NUM_FIRMWARE_IMAGES+1)))
        exit 0
        ;;

    # Any other input - we provide additional validation afterwards
    *)
        if [[ $REPLY -lt $MIN_VALID_SELECTION || $REPLY -gt $MAX_VALID_SELECTION ]]; then
            echo "Invalid selection -- out of range"
            continue
        fi
        break
        ;;
    esac
done

# Double check a firmware image was elected (ie: sending EOF will close the above prompt w/o selecting an image)
FIRMWARE_IMAGE_ABS=$(readlink -f $FIRMWARE_DIR/${FIRMWARE_IMAGES[$(($REPLY-1))]})
if [[ -z $REPLY || -z $FIRMWARE_IMAGE_ABS ]]; then
    echo "No firmware image selected. Exiting"
    exit 1
fi

echo "Select firmware image $REPLY: $FIRMWARE_IMAGE_ABS"
echo "Running container $CONTAINER_IMAGE with args $QEMU_RUN_ARGS"
xhost +
$CONTAINER_MANAGER run --rm -it \
    -p 10000-10001:10000-10001 \
    -e DISPLAY=$DISPLAY \
    -e START_TELNET=$START_TELNET \
    -e START_DEBUG=$START_DEBUG \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v $FIRMWARE_IMAGE_ABS:/firmware.img \
    -v $(pwd)/src:/src \
    $CONTAINER_IMAGE $QEMU_RUN_ARGS