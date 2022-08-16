#!/bin/bash -x

START_DIR="$1"
if [ -v ${1} ]; then
    echo "Please provide a build directory path."
    exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

NDK_LOCATION="/Users/edward/Library/Android/sdk/ndk/24.0.8215888/"

#Variables
NUM_THREADS=4
CMAKE_BUILD_TYPE="Debug"
CMAKE_BUILD_SETTINGS="-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} -DCMAKE_TOOLCHAIN_FILE='${NDK_LOCATION}/build/cmake/android.toolchain.cmake'"
#Build settings
BUILD_OGRE=false
BUILD_BULLET=false
BUILD_SQUIRREL=false
BUILD_ENTITYX=false
BUILD_COLIBRI=false
BUILD_DETOUR=false
BUILD_SDL2=true

INSTALL_DIR="${START_DIR}/avBuilt/${CMAKE_BUILD_TYPE}"

#Ogre
OGRE_TARGET_BRANCH="v2-3"
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

#SDL2
SDL2_TARGET_BRANCH="release-2.0.14"
SDL2_DIR="${START_DIR}/SDL2"

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
    cmake ${CMAKE_BUILD_SETTINGS} -DCMAKE_CXX_STANDARD=11 \
        -DANDROID_ABI=arm64-v8a \
        -DANDROID_NATIVE_API_LEVEL=24 \
        ../..
    make -j${NUM_THREADS}
    make install

    #Build Ogre
    cd ${OGRE_DIR}
    ln -s ${OGRE_DEPS_DIR}/build/${CMAKE_BUILD_TYPE}/ogredeps DependenciesAndroid
    mkdir -p ${OGRE_BIN_DIR}
    cd ${OGRE_BIN_DIR}
    cmake ${CMAKE_BUILD_SETTINGS} \
        -DANDROID_ABI=arm64-v8a \
        -DANDROID_NATIVE_API_LEVEL=24 \
        -DOGRE_BUILD_PLATFORM_ANDROID=1 \
        -DOGRE_DEPENDENCIES_DIR=${OGRE_DIR}/DependenciesAndroid \
        -DOGRE_SIMD_NEON=OFF \
        -DOGRE_SIMD_SSE2=OFF \
        -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/ogre2 -DCMAKE_CXX_STANDARD=11 \
        ../..
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
    cmake ${CMAKE_BUILD_SETTINGS} -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/bullet3 \
        -DBUILD_CLSOCKET=OFF \
        -DINSTALL_LIBS=True \
        -DBUILD_BULLET_ROBOTICS_EXTRA=False \
        -DBUILD_BULLET_ROBOTICS_GUI_EXTRA=False \
        -DBUILD_BULLET2_DEMOS=False \
        -DBUILD_CPU_DEMOS=False \
        -DBUILD_OPENGL3_DEMOS=False \
        -DBUILD_UNIT_TESTS=False \
        -DBUILD_EXTRAS=False \
        ../..
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
    #git apply /Users/edward/Documents/avBuild/macBuild/iosSquirrelPatch.diff
    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}
    cmake ${CMAKE_BUILD_SETTINGS} -DDISABLE_DYNAMIC=True -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/squirrel ../..
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
    cmake ${CMAKE_BUILD_SETTINGS} -DENTITYX_BUILD_SHARED=False -DENTITYX_BUILD_TESTING=False -DENTITYX_RUN_BENCHMARKS=False -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/entityx ../..
    make -j${NUM_THREADS} || exit 1
    make install
else
    echo "Skipping entityX build"
fi

#ColibriGUI
if [ $BUILD_COLIBRI = true ]; then
    echo "building ColibriGUI"

    git clone --recurse-submodules --shallow-submodules --branch ${COLIBRI_TARGET_BRANCH} https://github.com/darksylinc/colibrigui.git ${COLIBRI_DIR}
    cd ${COLIBRI_DIR}

    cd Dependencies
    rm Ogre
    #Link relative to the build directory, not the container.
    ln -s ../../${OGRE_DIR_NAME} Ogre
    cd ..

    cd Dependencies/sds_library
    #git apply ${SCRIPT_DIR}/../linuxBuild/sds_patch.diff
    git apply ${SCRIPT_DIR}/androidSdsDiff.diff
    cd ${COLIBRI_DIR}

    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}
    #Force c++11 to solve some problems with bleeding edge compilers.
    cmake ${CMAKE_BUILD_SETTINGS} -DOGRE_SOURCE=${OGRE_DIR} -DOGRE_BINARIES=${OGRE_BIN_DIR} -DANDROID=TRUE -DCOLIBRIGUI_LIB_ONLY=TRUE -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/colibri -DCOLIBRIGUI_FLEXIBILITY_LEVEL=2 -DCMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS}" ../..
    make -j${NUM_THREADS} || exit 1

    #Custom install for colibrigui, as the cmake install gave me problems.

    INSTALL_BASE=${INSTALL_DIR}/colibri
    rm -rf ${INSTALL_BASE}
    mkdir ${INSTALL_BASE}
    mkdir -p ${INSTALL_BASE}/include
    cp -r ${COLIBRI_DIR}/include/ColibriGui ${INSTALL_BASE}/include/ColibriGui
    cp -r ${COLIBRI_DIR}/bin/Data ${INSTALL_BASE}/data
    #Have to specify these flags to prevent the symlink being copied.
    #This is different from the gnu cp flags because macos uses bsd commands.
    cp -RH ${COLIBRI_DIR}/Dependencies ${INSTALL_BASE}/dependencies
    mkdir -p ${INSTALL_BASE}/lib64
    cd ${COLIBRI_DIR}
    find . -name "*.a" -type f -exec cp {} ${INSTALL_BASE}/lib64 \;
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
    cmake ${CMAKE_BUILD_SETTINGS} -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/recastdetour -DRECASTNAVIGATION_DEMO=FALSE -DRECASTNAVIGATION_EXAMPLES=FALSE -DRECASTNAVIGATION_TESTS=FALSE ../..
    make -j${NUM_THREADS} || exit 1
    make install

else
    echo "Skipping RecastDetour build"
fi

#SDL2
#Generally provided by the distro and dependencies as well, however it's convenient for the windows build.
if [ $BUILD_SDL2 = true ]; then
    echo "building SDL2"
    cd $START_DIR

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

#Clone helper libs that don't directly need compiling.
cd ${START_DIR}
git clone https://github.com/wjakob/filesystem.git ${INSTALL_DIR}/filesystem
git clone https://github.com/gabime/spdlog.git ${INSTALL_DIR}/spdlog
git clone https://github.com/leethomason/tinyxml2.git ${INSTALL_DIR}/tinyxml2

#Copy in the rapidjson provided by ogre, not the latest cloned one.
mkdir -p ${INSTALL_DIR}/rapidjson/include
cp -r ${OGRE_DEPS_DIR}/build/${CMAKE_BUILD_TYPE}/ogredeps/include/rapidjson ${INSTALL_DIR}/rapidjson/include