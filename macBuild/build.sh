#!/bin/bash -x

#brew install cmake wget

START_DIR="${1}"
if [ -z "$1" ]; then
    echo "Please provide a build directory path."
    exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo "Building to path ${START_DIR}"

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

#Variables
NUM_THREADS=4
CMAKE_BUILD_TYPE="Debug"
CMAKE_BUILD_SETTINGS="-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} -DCMAKE_OSX_ARCHITECTURES=${TARGET_ARCH} -G Xcode"
#Build settings
BUILD_OGRE=true
BUILD_BULLET=true
BUILD_SQUIRREL=true
BUILD_ENTITYX=true
BUILD_COLIBRI=true
BUILD_DETOUR=true
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
    cd ${OGRE_DIR}
    git clone --recurse-submodules --shallow-submodules https://github.com/OGRECave/ogre-next-deps ${OGRE_DEPS_DIR}

    STATIC_FLAGS=""
    #STATIC_FLAGS="-DOGRE_STATIC=TRUE -DOGRE_BUILD_LIBS_AS_FRAMEWORKS=FALSE"
    #Build dependencies first.
    cd ${OGRE_DEPS_DIR}
    #Bodge for macos arm which seems to be broken with the most recent freeimage stuff.
    git apply ${SCRIPT_DIR}/macosNeonOptimisation.diff
    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}
    #Force c++11 because freeimage seems broken in places.
    cmake ${CMAKE_BUILD_SETTINGS} ${STATIC_FLAGS} -DOGREDEPS_BUILD_SHADERC=False -DOGREDEPS_BUILD_REMOTERY=False -DOGREDEPS_BUILD_OPENVR=False -DCMAKE_CXX_STANDARD=11 ../..
    xcodebuild -scheme ALL_BUILD -project OGREDEPS.xcodeproj
    xcodebuild -scheme install -project OGREDEPS.xcodeproj

    #Build Ogre
    cd ${OGRE_DIR}
    ln -s ${OGRE_DEPS_DIR}/build/${CMAKE_BUILD_TYPE}/ogredeps Dependencies

    mkdir -p ${OGRE_BIN_DIR}
    cd ${OGRE_BIN_DIR}

    cmake ${CMAKE_BUILD_SETTINGS} \
    -DCMAKE_CXX_FLAGS="-I/usr/local/include -F/Library/Frameworks" \
    ${STATIC_FLAGS} \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/ogre2 -DCMAKE_CXX_STANDARD=11 -DOGRE_BUILD_RENDERSYSTEM_GL3PLUS=OFF ../..
    xcodebuild -scheme ALL_BUILD -project OGRE.xcodeproj
    xcodebuild -scheme install -project OGRE.xcodeproj
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
    cmake ${CMAKE_BUILD_SETTINGS} -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/bullet3 -DINSTALL_LIBS=True \
        -DBUILD_BULLET_ROBOTICS_EXTRA=False -DBUILD_BULLET_ROBOTICS_GUI_EXTRA=False -DBUILD_BULLET2_DEMOS=False -DBUILD_CPU_DEMOS=False -DBUILD_OPENGL3_DEMOS=False -DBUILD_UNIT_TESTS=False -DBUILD_EXTRAS=False ../..
    xcodebuild -scheme ALL_BUILD -project BULLET_PHYSICS.xcodeproj
    xcodebuild -scheme install -project BULLET_PHYSICS.xcodeproj
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
    xcodebuild -scheme ALL_BUILD -project squirrel.xcodeproj
    xcodebuild -scheme install -project squirrel.xcodeproj
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
    cmake ${CMAKE_BUILD_SETTINGS} -DENTITYX_BUILD_SHARED=False -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/entityx ../..
    xcodebuild -scheme ALL_BUILD -project EntityX.xcodeproj
    xcodebuild -scheme install -project EntityX.xcodeproj
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

    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}
    #Force c++11 to solve some problems with bleeding edge compilers.
    cmake ${CMAKE_BUILD_SETTINGS} -DOGRE_SOURCE=${OGRE_DIR} -DOGRE_BINARIES=${OGRE_BIN_DIR} -DCOLIBRIGUI_LIB_ONLY=TRUE -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/colibri -DCOLIBRIGUI_FLEXIBILITY_LEVEL=2 -DCMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS} -std=c++11" ../..
    xcodebuild -scheme ALL_BUILD -project ColibriGui.xcodeproj

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
    xcodebuild -scheme ALL_BUILD -project RecastNavigation.xcodeproj
    xcodebuild -scheme install -project RecastNavigation.xcodeproj
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
    xcodebuild -scheme ALL_BUILD -project SDL2.xcodeproj
    xcodebuild -scheme install -project SDL2.xcodeproj
else
    echo "Skipping SDL2 build"
fi

#googletest
    echo "building googletest"

    git clone https://github.com/google/googletest.git ${GOOGLETEST_DIR}
    cd ${GOOGLETEST_DIR}
    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}
    cmake ${CMAKE_BUILD_SETTINGS} -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/googletest ../..
    xcodebuild -scheme ALL_BUILD -project googletest-distribution.xcodeproj
    xcodebuild -scheme install -project googletest-distribution.xcodeproj

#Clone helper libs that don't directly need compiling.
cd ${START_DIR}
git clone https://github.com/wjakob/filesystem.git ${INSTALL_DIR}/filesystem
git clone https://github.com/gabime/spdlog.git ${INSTALL_DIR}/spdlog
git clone https://github.com/leethomason/tinyxml2.git ${INSTALL_DIR}/tinyxml2

#Copy in the rapidjson provided by ogre, not the latest cloned one.
mkdir -p ${INSTALL_DIR}/rapidjson/include
cp -r ${OGRE_DEPS_DIR}/build/${CMAKE_BUILD_TYPE}/ogredeps/include/rapidjson ${INSTALL_DIR}/rapidjson/include
