#!/bin/bash -x

START_DIR="$1"
if [ -v ${1} ]; then
    echo "Please provide a build directory path."
    exit 1
fi

#Variables
NUM_THREADS=4
CMAKE_BUILD_TYPE="Debug"
CMAKE_BUILD_SETTINGS="-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} -DCMAKE_OSX_ARCHITECTURES=x86_64 -G Xcode"
#Build settings
BUILD_OGRE=false
BUILD_BULLET=true
BUILD_SQUIRREL=true
BUILD_ENTITYX=true
BUILD_COLIBRI=false
BUILD_DETOUR=true
BUILD_SDL2=true

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

#SDL2
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
    #git clone --recurse-submodules --shallow-submodules https://github.com/OGRECave/ogre-next-deps ${OGRE_DEPS_DIR}

    #Build dependencies first.
    # cd ${OGRE_DEPS_DIR}
    # mkdir -p build/${CMAKE_BUILD_TYPE}
    # cd build/${CMAKE_BUILD_TYPE}
    # #Force c++11 because freeimage seems broken in places.
    # cmake ${CMAKE_BUILD_SETTINGS} -DCMAKE_CXX_STANDARD=11 ../..
    # xcodebuild -scheme zziplib -project OGREDEPS.xcodeproj
    # xcodebuild -scheme zlib -project OGREDEPS.xcodeproj
    # xcodebuild -scheme FreeImage -project OGREDEPS.xcodeproj
    # make -j${NUM_THREADS}
    # make install

    #Build Ogre
    cd ${OGRE_DIR}
    #ln -s ${OGRE_DEPS_DIR}/build/${CMAKE_BUILD_TYPE}/ogredeps Dependencies
    #Clear up some bugs in ogre.
    #git apply git.diff
    git apply /Users/edward/Documents/avBuild/macBuild/git.diff
    #This material breaks the samples when using metal.
    mv ${OGRE_DIR}/Samples/Media/2.0/scripts/materials/Common/HiddenAreaMeshVr.material ${OGRE_DIR}/Samples/Media/2.0/scripts/materials/Common/HiddenAreaMeshVr.materialll

    mkdir -p ${OGRE_BIN_DIR}
    cd ${OGRE_BIN_DIR}

    cmake ${CMAKE_BUILD_SETTINGS} \
    -DCMAKE_CXX_FLAGS="-I/usr/local/include -F/Library/Frameworks" \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/ogre2 -DCMAKE_CXX_STANDARD=11 -DOGRE_BUILD_RENDERSYSTEM_GL3PLUS=OFF ../..
    xcodebuild -scheme ALL_BUILD -project OGRE.xcodeproj
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
    cmake ${CMAKE_BUILD_SETTINGS} -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/entityx ../..
    xcodebuild -scheme ALL_BUILD -project EntityX.xcodeproj
    xcodebuild -scheme install -project EntityX.xcodeproj
else
    echo "Skipping entityX build"
fi

#ColibriGUI
if [ $BUILD_COLIBRI = true ]; then
    echo "building ColibriGUI"

    git clone --branch ${COLIBRI_TARGET_BRANCH} https://github.com/edherbert/colibrigui.git ${COLIBRI_DIR}
    cd ${COLIBRI_DIR}

    cd Dependencies
    rm Ogre
    #Link relative to the build directory, not the container.
    ln -s ../../${OGRE_DIR_NAME} Ogre
    cd ..

    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}
    #Force c++11 to solve some problems with bleeding edge compilers.
    cmake ${CMAKE_BUILD_SETTINGS} -DOGRE_SOURCE=${OGRE_DIR} -DOGRE_BINARIES=${OGRE_BIN_DIR} -DCOLIBRIGUI_LIB_ONLY=TRUE -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/colibri -DCMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS} -std=c++11" ../..
    make -j${NUM_THREADS} || exit 1
    make install
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

    #They don't host a git repo so just get the source tarball.
    SDL2_FILE_NAME="SDL2-2.0.14"
    SDL2_FILE_NAME_TAR="${SDL2_FILE_NAME}.tar.gz"
    if [ ! -f ${SDL2_FILE_NAME_TAR} ]; then
        wget https://www.libsdl.org/release/${SDL2_FILE_NAME_TAR}
    fi
    tar -xf ${SDL2_FILE_NAME_TAR}
    cd ${SDL2_FILE_NAME}
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
    # make -j${NUM_THREADS} || exit 1
    # make install

#Clone helper libs that don't directly need compiling.
cd ${START_DIR}
git clone https://github.com/wjakob/filesystem.git ${INSTALL_DIR}/filesystem
git clone https://github.com/gabime/spdlog.git ${INSTALL_DIR}/spdlog
git clone https://github.com/leethomason/tinyxml2.git ${INSTALL_DIR}/tinyxml2
#git clone https://github.com/Tencent/rapidjson.git ${INSTALL_DIR}/rapidjson

#Copy in the rapidjson provided by ogre, not the latest cloned one.
mkdir -p ${INSTALL_DIR}/rapidjson/include
cp -r ${OGRE_DEPS_DIR}/build/${CMAKE_BUILD_TYPE}/ogredeps/include/rapidjson ${INSTALL_DIR}/rapidjson/include
