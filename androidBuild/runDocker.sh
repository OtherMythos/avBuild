#!/bin/bash -x

docker run --rm --platform linux/amd64 \
    -v "${1}:/avbuild/build" \
    -it avbuild-android-image \
    /bin/bash
