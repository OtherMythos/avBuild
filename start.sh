#!/bin/bash -x

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
LINUX_BUILD_DIR="${SCRIPT_DIR}/linuxBuild/"
if [ ! -d ${LINUX_BUILD_DIR} ]; then
    echo "Could not find linuxBuild scripts in ${LINUX_BUILD_DIR} You probably have a broken repo."
    exit 1
fi

if [ -v ${1} ]; then
    echo "Please provide a path of where to build."
    exit 1
fi
if [ ! -d ${1} ]; then
    echo "provided directory does not exist"
    exit 1
fi
echo "Building to ${1}"

export _UID=$(id -u)
export _GID=$(id -g)
# docker kill avbuild-container ||
# docker container rm avbuild-container ||
docker run --rm \
    --user ${_UID}:${_GID} \
    -v "${1}:/avbuild/build" \
    -v "${LINUX_BUILD_DIR}:/avbuild/scripts/linuxBuild" \
    -it avbuild-image \
    /bin/bash
