#!/bin/bash -x

START_DIR="$1"
if [ -v ${1} ]; then
    echo "Please provide a build directory path."
    exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

#Variables
NUM_THREADS=4
CMAKE_BUILD_TYPE="Debug"
CMAKE_BUILD_SETTINGS="-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
#Build settings
BUILD_OGRE=false
BUILD_SQUIRREL=false
BUILD_DETOUR=true
BUILD_SDL2=false
BUILD_NFD=false

INSTALL_DIR="${START_DIR}/avBuilt/${CMAKE_BUILD_TYPE}"

#Ogre
OGRE_TARGET_BRANCH="v2-1"
OGRE_DIR_NAME="ogre2"
OGRE_DIR="${START_DIR}/${OGRE_DIR_NAME}"
OGRE_BIN_DIR="${OGRE_DIR}/build/${CMAKE_BUILD_TYPE}"
OGRE_DEPS_DIR="${START_DIR}/ogre-next-deps"

#Squirrel
SQUIRREL_TARGET_BRANCH="master"
SQUIRREL_DIR="${START_DIR}/squirrel"

#RecastDetour
DETOUR_TARGET_BRANCH="master"
DETOUR_DIR="${START_DIR}/recastdetour"

#SDL2
SDL2_TARGET_BRANCH="release-2.0.14"
SDL2_DIR="${START_DIR}/SDL2"

#nativefiledialog
NFD_TARGET_BRANCH="master"
NFD_DIR="${START_DIR}/nativefiledialog"

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
    cmake ${CMAKE_BUILD_SETTINGS} -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/ogre2 -DCMAKE_CXX_STANDARD=11 ../..
    make -j${NUM_THREADS} || exit 1
    make install
else
    echo "Skipping ogre build"
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

#RecastDetour
if [ $BUILD_DETOUR = true ]; then
    echo "building RecastDetour"

    git clone --branch ${DETOUR_TARGET_BRANCH} https://github.com/recastnavigation/recastnavigation.git ${DETOUR_DIR}
    cd ${DETOUR_DIR}
    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}
    cmake ${CMAKE_BUILD_SETTINGS} -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/recastdetour -DRECASTNAVIGATION_TESTS=FALSE ../..
    make -j${NUM_THREADS} || exit 1
    make install
else
    echo "Skipping RecastDetour build"
fi

#SDL2
if [ $BUILD_SDL2 = true ]; then
    echo "building SDL2"

    git clone --branch ${SDL2_TARGET_BRANCH} https://github.com/libsdl-org/SDL.git ${SDL2_DIR}
    cd ${SDL2_DIR}
    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}
    cmake ${CMAKE_BUILD_SETTINGS} -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/SDL2 -DSDL_SHARED=FALSE ../..
    make -j${NUM_THREADS} || exit 1
    make install
else
    echo "Skipping SDL2 build"
fi

#nativefiledialog
if [ $BUILD_NFD = true ]; then
    echo "building nativefiledialog"

    git clone --branch ${NFD_TARGET_BRANCH} https://github.com/btzy/nativefiledialog-extended.git ${NFD_DIR}
    cd ${NFD_DIR}
    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}
    cmake ${CMAKE_BUILD_SETTINGS} -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/nativefiledialog ../..
    make -j${NUM_THREADS} || exit 1
    make install

    # cd ${NFD_DIR}/build/gmake_linux
    # make config=debug_x64 || exit 1

    # INSTALL_BASE=${INSTALL_DIR}/nativefiledialog
    # rm -rf ${INSTALL_BASE}
    # mkdir ${INSTALL_BASE}
    # cp -r ${NFD_DIR}/src ${INSTALL_BASE}
    # mkdir -p ${INSTALL_BASE}/lib
    # find ${NFD_DIR}/build/lib -name "*.a" -type f -exec cp {} ${INSTALL_BASE}/lib \;
else
    echo "Skipping nativefiledialog build"
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
git clone https://github.com/wjakob/filesystem.git ${INSTALL_DIR}/filesystem
git clone https://github.com/gabime/spdlog.git ${INSTALL_DIR}/spdlog
git clone https://github.com/leethomason/tinyxml2.git ${INSTALL_DIR}/tinyxml2

git clone https://github.com/ocornut/imgui.git ${INSTALL_DIR}/imgui
cd ${INSTALL_DIR}/imgui
git checkout docking

#Copy in the rapidjson provided by ogre, not the latest cloned one.
mkdir -p ${INSTALL_DIR}/rapidjson/include
cp -r ${OGRE_DEPS_DIR}/build/${CMAKE_BUILD_TYPE}/ogredeps/include/rapidjson ${INSTALL_DIR}/rapidjson/include
