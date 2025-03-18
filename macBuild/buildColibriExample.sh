#!/bin/bash -x

#Build the colibrigui examples, building its dependencies at the same time.

START_DIR="$1"
if [ -v ${1} ]; then
    echo "Please provide a build directory path."
    exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

#Fill with either 'x86_64' or 'arm64' to override the platform detection.
TARGET_ARCH=""
if [ -z ${TARGET_ARCH} ]; then
    TARGET_ARCH=$(arch)
    #For historical reasons arch might return this on x86 processors.
    if [ ${TARGET_ARCH} == "i386" ]; then
        TARGET_ARCH="x86_64"
    fi
    echo "Assuming architecture to be ${TARGET_ARCH}"
else
    echo "Using architecture ${TARGET_ARCH}"
fi

CMAKE_BUILD_TYPE="Debug"
CMAKE_BUILD_SETTINGS="-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} -DCMAKE_OSX_ARCHITECTURES=${TARGET_ARCH} -G Xcode"

OGRE_TARGET_BRANCH="v2-3"
OGRE_DIR_NAME="ogre2"
OGRE_DIR="${START_DIR}/${OGRE_DIR_NAME}"
OGRE_BIN_DIR="${OGRE_DIR}/build/"
OGRE_DEPS_DIR="${START_DIR}/ogre-next-deps"

COLIBRI_TARGET_BRANCH="master"
COLIBRI_DIR="${START_DIR}/colibri"

BUILD_OGRE=true
BUILD_COLIBRI=true

if [ $BUILD_OGRE = true ]; then
    echo "Building ogre."

    #Clone
    git clone --branch ${OGRE_TARGET_BRANCH} https://github.com/OGRECave/ogre-next ${OGRE_DIR}
    cd ${OGRE_DIR}
    git clone --recurse-submodules --shallow-submodules https://github.com/OGRECave/ogre-next-deps ${OGRE_DEPS_DIR}

    #Build dependencies first.
    cd ${OGRE_DEPS_DIR}
    git apply ${SCRIPT_DIR}/macosNeonOptimisation.diff
    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}
    #Force c++11 because freeimage seems broken in places.
    cmake ${CMAKE_BUILD_SETTINGS} -DOGRE_STATIC=TRUE -DOGREDEPS_BUILD_SHADERC=False -DOGREDEPS_BUILD_REMOTERY=False -DOGREDEPS_BUILD_OPENVR=False -DCMAKE_CXX_STANDARD=11 ../..
    xcodebuild -scheme ALL_BUILD -project OGREDEPS.xcodeproj
    xcodebuild -scheme install -project OGREDEPS.xcodeproj

    #Build Ogre
    cd ${OGRE_DIR}
    ln -s ${OGRE_DEPS_DIR}/build/${CMAKE_BUILD_TYPE}/ogredeps Dependencies

    mkdir -p ${OGRE_BIN_DIR}
    cd ${OGRE_BIN_DIR}

    cmake ${CMAKE_BUILD_SETTINGS} \
    -DCMAKE_CXX_FLAGS="-I/usr/local/include -F/Library/Frameworks" \
    -DOGRE_STATIC=TRUE -DOGRE_BUILD_SAMPLES2=False \
    -DCMAKE_CXX_STANDARD=11 -DOGRE_BUILD_RENDERSYSTEM_GL3PLUS=OFF -DOGRE_BUILD_LIBS_AS_FRAMEWORKS=False ..
    xcodebuild -scheme ALL_BUILD -project OGRE.xcodeproj

    ln -s ../build Debug
fi


if [ $BUILD_COLIBRI = true ]; then
    #Colibrigui
    echo "building ColibriGUI"

    git clone --recurse-submodules --shallow-submodules --branch ${COLIBRI_TARGET_BRANCH} https://github.com/darksylinc/colibrigui.git ${COLIBRI_DIR}
    cd ${COLIBRI_DIR}

    cd Dependencies
    rm Ogre
    #Link relative to the build directory, not the container.
    ln -s ../../${OGRE_DIR_NAME} Ogre
    cd ..

    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}
    #Force c++11 to solve some problems with bleeding edge compilers.
    cmake ${CMAKE_BUILD_SETTINGS} -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/colibri -DCMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS} -std=c++11" ../..
    xcodebuild -scheme ALL_BUILD -project ColibriGui.xcodeproj
fi
