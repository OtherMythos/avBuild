#!/bin/bash -x

START_DIR="$1"
if [ -v ${1} ]; then
    echo "Please provide a build directory path."
    exit 1
fi

#Variables
NUM_THREADS=4
CMAKE_BUILD_TYPE="Debug"
CMAKE_BUILD_SETTINGS="-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
#Build settings
BUILD_OGRE=true
BUILD_BULLET=true
BUILD_SQUIRREL=true
BUILD_ENTITYX=true
BUILD_COLIBRI=true
BUILD_DETOUR=true

INSTALL_DIR="${START_DIR}/avBuilt/${CMAKE_BUILD_TYPE}"

#Ogre
OGRE_TARGET_BRANCH="v2-2"
OGRE_DIR_NAME="ogre2"
OGRE_DIR="${START_DIR}/${OGRE_DIR_NAME}"
OGRE_BIN_DIR="${OGRE_DIR}/build/${CMAKE_BUILD_TYPE}"
OGRE_DEPS_DIR="${START_DIR}/ogre-next-deps"

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

#RecastDetour
DETOUR_TARGET_BRANCH="master"
DETOUR_DIR="${START_DIR}/recastdetour"

GOOGLETEST_DIR="${START_DIR}/googletest"

#Start
cd ${START_DIR}

#Ogre
if [ $BUILD_OGRE = true ]; then
    echo "Building ogre."

    #Clone
    git clone --branch ${OGRE_TARGET_BRANCH} https://github.com/OGRECave/ogre-next ${OGRE_DIR}
    #cd ${OGRE_DIR}
    git clone --recurse-submodules --shallow-submodules https://github.com/OGRECave/ogre-next-deps ${OGRE_DEPS_DIR}

    #Build dependencies first.
    cd ${OGRE_DEPS_DIR}
    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}
    #Force c++11 because freeimage seems broken in places.
    cmake ${CMAKE_BUILD_SETTINGS} -DCMAKE_CXX_STANDARD=11 ../..
    make -j${NUM_THREADS}
    make install

    #Build Ogre
    cd ${OGRE_DIR}
    ln -s ${OGRE_DEPS_DIR}/build/${CMAKE_BUILD_TYPE}/ogredeps Dependencies
    mkdir -p ${OGRE_BIN_DIR}
    cd ${OGRE_BIN_DIR}
    #Bung the installed files off somewhere else.
    mkdir installDir
    cmake ${CMAKE_BUILD_SETTINGS} -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/ogre2 -DCMAKE_CXX_STANDARD=11 ../..
    make -j${NUM_THREADS} || exit 1
    make install
else
    echo "Skipping ogre build"
fi

#Bullet
if [ $BUILD_BULLET = true ]; then
    echo "building bullet"

    git clone --branch ${BULLET_TARGET_BRANCH} https://github.com/bulletphysics/bullet3.git ${BULLET_DIR}
    cd ${BULLET_DIR}
    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}
    cmake ${CMAKE_BUILD_SETTINGS} -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/bullet ../..
    make -j${NUM_THREADS} || exit 1
    make install
else
    echo "Skipping bullet build"
fi

#Squirrel
if [ $BUILD_SQUIRREL = true ]; then
    echo "building squirrel"

    git clone --branch ${SQUIRREL_TARGET_BRANCH} https://github.com/albertodemichelis/squirrel.git ${SQUIRREL_DIR}
    cd ${SQUIRREL_DIR}
    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}
    cmake ${CMAKE_BUILD_SETTINGS} -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/squirrel ../..
    make -j${NUM_THREADS} || exit 1
    make install
else
    echo "Skipping squirrel build"
fi

#EntityX
if [ $BUILD_ENTITYX = true ]; then
    echo "building entityX"

    git clone --branch ${ENTITYX_TARGET_BRANCH} https://github.com/alecthomas/entityx.git ${ENTITYX_DIR}
    cd ${ENTITYX_DIR}
    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}
    cmake ${CMAKE_BUILD_SETTINGS} -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/entityx ../..
    make -j${NUM_THREADS} || exit 1
    make install
else
    echo "Skipping entityX build"
fi

#ColibriGUI
if [ $BUILD_COLIBRI = true ]; then
    echo "building ColibriGUI"

    git clone --branch ${COLIBRI_TARGET_BRANCH} https://github.com/darksylinc/colibrigui.git ${COLIBRI_DIR}
    cd ${COLIBRI_DIR}
    #cd Dependencies
    #rm Ogre
    #Link relative to the build directory, not the container.
    #ln -s ../../${OGRE_DIR_NAME} Ogre
    #cd ..
    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}
    #Force c++11 to solve some problems with bleeding edge compilers.
    cmake ${CMAKE_BUILD_SETTINGS} -DOGRE_SOURCE=${OGRE_DIR} -DOGRE_BINARIES=${OGRE_BIN_DIR} -DCOLIBRIGUI_LIB_ONLY=TRUE -DCMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS} -std=c++11" ../..
    make -j${NUM_THREADS} || exit 1
else
    echo "Skipping colibri build"
fi

#RecastDetour
if [ $BUILD_DETOUR = true ]; then
    echo "building RecastDetour"

    git clone --branch ${DETOUR_TARGET_BRANCH} https://github.com/recastnavigation/recastnavigation.git ${DETOUR_DIR}
    cd ${DETOUR_DIR}
    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}
    cmake ${CMAKE_BUILD_SETTINGS} -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/recastdetour DRECASTNAVIGATION_DEMO=FALSE -DRECASTNAVIGATION_EXAMPLES=FALSE -DRECASTNAVIGATION_TESTS=FALSE ../..
    make -j${NUM_THREADS} || exit 1
    make install
else
    echo "Skipping RecastDetour build"
fi

#googletest
    echo "building googletest"

    git clone https://github.com/google/googletest.git ${GOOGLETEST_DIR}
    cd ${GOOGLETEST_DIR}
    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}
    cmake ${CMAKE_BUILD_SETTINGS} -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/googletest ../..
    make -j${NUM_THREADS} || exit 1
    make install

#Clone helper libs that don't directly need compiling.
cd ${START_DIR}
git clone https://github.com/wjakob/filesystem.git
git clone https://github.com/gabime/spdlog.git
git clone https://github.com/leethomason/tinyxml2.git
git clone https://github.com/Tencent/rapidjson.git
