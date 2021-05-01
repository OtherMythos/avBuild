#!/bin/bash -x

#Variables
START_DIR="/avbuild/build"
NUM_THREADS=4
CMAKE_BUILD_TYPE="Debug"
CMAKE_BUILD_SETTINGS="-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
#Build settings
BUILD_OGRE=false
BUILD_BULLET=false
BUILD_SQUIRREL=false
BUILD_ENTITYX=false
BUILD_COLIBRI=true

#Ogre
OGRE_TARGET_BRANCH="v2-2"
OGRE_DIR_NAME="ogre2"
OGRE_DIR="${START_DIR}/${OGRE_DIR_NAME}"
OGRE_BIN_DIR="${OGRE_DIR}/build/${CMAKE_BUILD_TYPE}"

#Bullet
BULLET_TARGET_BRANCH="master"
BULLET_DIR="${START_DIR}/bullet3"

#Squirrel
SQUIRREL_TARGET_BRANCH="master"
SQUIRREL_DIR="${START_DIR}/squirrel"

#EntityX
ENTITYX_TARGET_BRANCH="master"
ENTITYX_DIR="${START_DIR}/entityx"

#ColibriGUI
COLIBRI_TARGET_BRANCH="master"
COLIBRI_DIR="${START_DIR}/colibri"

GOOGLETEST_DIR="${START_DIR}/googletest"

#Start
cd ${START_DIR}

#Ogre
if [ $BUILD_OGRE = true ]; then
    echo "Building ogre."

    #Clone
    git clone --branch ${OGRE_TARGET_BRANCH} https://github.com/OGRECave/ogre-next ${OGRE_DIR}
    cd ${OGRE_DIR}
    git clone --recurse-submodules --shallow-submodules https://github.com/OGRECave/ogre-next-deps Dependencies

    #Build dependencies first.
    cd Dependencies
    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}
    cmake ${CMAKE_BUILD_SETTINGS} ../..
    make -j${NUM_THREADS}
    make install

    #Build Ogre
    cd ${OGRE_DIR}
    mkdir -p ${OGRE_BIN_DIR}
    cd ${OGRE_BIN_DIR}
    #Seems to be a bug in Ogre, I have to run cmake twice.
    cmake ${CMAKE_BUILD_SETTINGS} ../..
    cmake ${CMAKE_BUILD_SETTINGS} ../..
    make -j${NUM_THREADS} || exit 1
else
    echo "Skipping ogre build"
fi

#Bullet
if [ $BUILD_BULLET = true ]; then
    echo "building bullet"

    git clone --branch ${BULLET_TARGET_BRANCH} https://github.com/bulletphysics/bullet3.git ${BULLET_DIR}
    cd ${BULLET_DIR}
    mkdir build
    cd build
    cmake ${CMAKE_BUILD_SETTINGS} ..
    make -j${NUM_THREADS}
else
    echo "Skipping bullet build"
fi

#Squirrel
if [ $BUILD_SQUIRREL = true ]; then
    echo "building squirrel"

    git clone --branch ${SQUIRREL_TARGET_BRANCH} https://github.com/albertodemichelis/squirrel.git ${SQUIRREL_DIR}
    cd ${SQUIRREL_DIR}
    mkdir build
    cd build
    cmake ${CMAKE_BUILD_SETTINGS} ..
    make -j${NUM_THREADS}
else
    echo "Skipping squirrel build"
fi

#EntityX
if [ $BUILD_ENTITYX = true ]; then
    echo "building entityX"

    git clone --branch ${ENTITYX_TARGET_BRANCH} https://github.com/alecthomas/entityx.git ${ENTITYX_DIR}
    cd ${ENTITYX_DIR}
    mkdir build
    cd build
    cmake ${CMAKE_BUILD_SETTINGS} ..
    make -j${NUM_THREADS}
else
    echo "Skipping entityX build"
fi

if [ $BUILD_ENTITYX = true ]; then
    echo "building entityX"

    git clone --branch ${ENTITYX_TARGET_BRANCH} https://github.com/alecthomas/entityx.git ${ENTITYX_DIR}
    cd ${ENTITYX_DIR}
    mkdir build
    cd build
    cmake ${CMAKE_BUILD_SETTINGS} ..
    make -j${NUM_THREADS}
else
    echo "Skipping entityX build"
fi

if [ $BUILD_COLIBRI = true ]; then
    echo "building ColibriGUI"

    git clone --branch ${COLIBRI_TARGET_BRANCH} https://github.com/darksylinc/colibrigui.git ${COLIBRI_DIR}
    cd ${COLIBRI_DIR}
    cd Dependencies
    rm Ogre
    #Link relative to the build directory, not the container.
    #ln -s ../../${OGRE_DIR_NAME} Ogre
    cd ..
    mkdir build
    cd build
    cmake ${CMAKE_BUILD_SETTINGS} -DOGRE_SOURCE=${OGRE_DIR} -DOGRE_BINARIES=${OGRE_BIN_DIR} -DCOLIBRIGUI_LIB_ONLY=TRUE ..
    make -j${NUM_THREADS} || exit 1
else
    echo "Skipping entityX build"
fi

#googletest
    echo "building googletest"

    git clone https://github.com/google/googletest.git ${GOOGLETEST_DIR}
    cd ${GOOGLETEST_DIR}
    mkdir build
    cd build
    cmake ${CMAKE_BUILD_SETTINGS} ..
    make -j${NUM_THREADS}

#Clone helper libs that don't directly need compiling.
cd ${START_DIR}
git clone https://github.com/wjakob/filesystem.git
git clone https://github.com/gabime/spdlog.git
git clone https://github.com/leethomason/tinyxml2.git
