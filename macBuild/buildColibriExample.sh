#!/bin/bash -x

#Build the colibrigui examples, building its dependencies at the same time.

START_DIR="$1"
if [ -v ${1} ]; then
    echo "Please provide a build directory path."
    exit 1
fi

CMAKE_BUILD_TYPE="Debug"
CMAKE_BUILD_SETTINGS="-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} -DCMAKE_OSX_ARCHITECTURES=x86_64 -G Xcode"

OGRE_TARGET_BRANCH="v2-2"
OGRE_DIR_NAME="ogre2"
OGRE_DIR="${START_DIR}/${OGRE_DIR_NAME}"
OGRE_BIN_DIR="${OGRE_DIR}/build/"
OGRE_DEPS_DIR="${START_DIR}/ogre-next-deps"

COLIBRI_TARGET_BRANCH="master"
COLIBRI_DIR="${START_DIR}/colibri"

BUILD_OGRE=false
BUILD_COLIBRI=true

if [ $BUILD_OGRE = true ]; then
    echo "Building ogre."

    #Clone
    git clone --branch ${OGRE_TARGET_BRANCH} https://github.com/OGRECave/ogre-next ${OGRE_DIR}
    cd ${OGRE_DIR}
    git clone --recurse-submodules --shallow-submodules https://github.com/OGRECave/ogre-next-deps ${OGRE_DEPS_DIR}

    #Build dependencies first.
    cd ${OGRE_DEPS_DIR}
    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}
    #Force c++11 because freeimage seems broken in places.
    cmake ${CMAKE_BUILD_SETTINGS} -DOGREDEPS_BUILD_SHADERC=False -DOGREDEPS_BUILD_REMOTERY=False -DOGREDEPS_BUILD_OPENVR=False -DCMAKE_CXX_STANDARD=11 ../..
    xcodebuild -scheme ALL_BUILD -project OGREDEPS.xcodeproj
    xcodebuild -scheme install -project OGREDEPS.xcodeproj

    #Build Ogre
    cd ${OGRE_DIR}
    ln -s ${OGRE_DEPS_DIR}/build/${CMAKE_BUILD_TYPE}/ogredeps Dependencies
    #This material breaks the samples when using metal.
    mv ${OGRE_DIR}/Samples/Media/2.0/scripts/materials/Common/HiddenAreaMeshVr.material ${OGRE_DIR}/Samples/Media/2.0/scripts/materials/Common/HiddenAreaMeshVr.materialll
    mv ${OGRE_DIR}/Samples/Media/2.0/scripts/materials/Common/RadialDensityMask.material ${OGRE_DIR}/Samples/Media/2.0/scripts/materials/Common/RadialDensityMask.materiallll

    mkdir -p ${OGRE_BIN_DIR}
    cd ${OGRE_BIN_DIR}

    cmake ${CMAKE_BUILD_SETTINGS} \
    -DCMAKE_CXX_FLAGS="-I/usr/local/include -F/Library/Frameworks" \
    -DCMAKE_CXX_STANDARD=11 -DOGRE_BUILD_RENDERSYSTEM_GL3PLUS=OFF -DOGRE_BUILD_LIBS_AS_FRAMEWORKS=False ..
    xcodebuild -scheme ALL_BUILD -project OGRE.xcodeproj

    ln -s ../build Debug
fi


if [ $BUILD_COLIBRI = true ]; then
    #Colibrigui
    echo "building ColibriGUI"

    git clone --branch ${COLIBRI_TARGET_BRANCH} https://github.com/darksylinc/colibrigui.git ${COLIBRI_DIR}
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
