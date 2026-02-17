#!/bin/bash
CONTAINER_MANAGER="docker"
CONTAINER_IMAGE="lightrtos-qemu-runner:latest"
HOST_DEPENDENCIES=("git" "xhost" "$CONTAINER_MANAGER")

usage() {
    echo "$0 <-h|--help> <--build-container> <--no-telnet> <--no-debug>"
    echo "  -h|--help: Shows this help message."
    echo "  --build-container: Force build a new container."
    echo "  --no-telnet: Do not auto-start telnet inside the container connected to USART. Will be available on port 10000."
    echo "  --no-debug: Do not auto-start gdb-multiarch inside the container. Will be available on port 10001."
}

cleanup() {
    :
}
trap cleanup "EXIT"

# missing_dependencies=""
# for dependency in $HOST_DEPENDENCIES; do
#     if ! $(which $dependency); then
#         missing_dependencies+=$dependency
#     fi
# done

# if $missing_dependencies; then
#     echo "Missing host dependencies: $missing_dependencies"
#     exit 1
# fi

# Parse args
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
echo "Running container $CONTAINER_IMAGE with args $QEMU_RUN_ARGS"
xhost +
$CONTAINER_MANAGER run --rm -it \
    -p 10000-10001:10000-10001 \
    -e DISPLAY=$DISPLAY \
    -e START_TELNET=$START_TELNET \
    -e START_DEBUG=$START_DEBUG \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v $firmware_image_abs:/firmware.img \
    -v $(pwd)/src:/src \
    $CONTAINER_IMAGE $QEMU_RUN_ARGS