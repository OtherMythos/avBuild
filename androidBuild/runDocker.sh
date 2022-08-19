#!/bin/bash -x

docker run --rm \
    -v "${1}:/avbuild/build" \
    -it avbuild-android-image \
    /bin/bash
