#!/bin/bash

if [ -v ${1} ]; then
    echo "Please provide a path of where to build."
    exit 1
fi
if [ ! -d ${1} ]; then
    echo "provided directory does not exist"
    exit 1
fi
echo "Building to ${1}"

# export UID=$(id -u)
# export GID=$(id -g)
# docker kill avbuild-container ||
# docker container rm avbuild-container ||
docker run --rm \
    -v "${1}:/avbuild/build" \
    -v "/home/edward/avBuild/linuxBuild:/avbuild/scripts/linuxBuild" \
    -it avbuild-image \
    /bin/bash
