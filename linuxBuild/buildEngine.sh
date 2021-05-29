#!/bin/bash -x

TARGET_BRANCH="particles"
CMAKE_BUILD_TYPE="Debug"

AV_LIBS_DIR="$1"
if [ -v ${1} ]; then
    echo "Please provide a path to the libs dir."
    exit 1
fi

git clone --branch ${TARGET_BRANCH} http://gitlab.com/edherbert/avEngine.git

cd avEngine
mkdir -p build/${CMAKE_BUILD_TYPE}
cd build/${CMAKE_BUILD_TYPE}

cmake -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} -DAV_LIBS_DIR=${AV_LIBS_DIR} ../..
make -j 4
