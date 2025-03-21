#!/bin/bash -x

START_DIR="$1"
if [ -v ${1} ]; then
    echo "Please provide a build directory path."
    exit 1
fi

CMAKE_BUILD_TYPE="Debug"
if [ ${2+x} ]; then
    CMAKE_BUILD_TYPE=${2}
    echo "Build type set to '${2}'"
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo "Builld type is ${CMAKE_BUILD_TYPE}"
#Variables
NUM_THREADS=4
CMAKE_BUILD_SETTINGS="-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
#Build settings
BUILD_OGRE=true
BUILD_BULLET=true
BUILD_SQUIRREL=true
BUILD_ENTITYX=true
BUILD_COLIBRI=true
BUILD_DETOUR=true
BUILD_SDL2=true
BUILD_OPENALSOFT=true
BUILD_LOTTIE=true
BUILD_NFD=true

INSTALL_DIR="${START_DIR}/avBuilt/${CMAKE_BUILD_TYPE}"

#Ogre
OGRE_TARGET_BRANCH="v3-0"
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
DETOUR_TARGET_BRANCH="main"
DETOUR_DIR="${START_DIR}/recastdetour"

#SDL2
SDL2_TARGET_BRANCH="release-2.30.2"
SDL2_DIR="${START_DIR}/SDL2"

#OpenALSoft
OPENALSOFT_TARGET_BRANCH="1.22.2"
OPENALSOFT_DIR="${START_DIR}/OpenALSoft"
LIBSNDFILE_TARGET_BRANCH="1.1.0"
LIBSNDFILE_DIR="${START_DIR}/libsndfile"

#nativefiledialog
NFD_TARGET_BRANCH="master"
NFD_DIR="${START_DIR}/nativefiledialog"

#Lottie
LOTTIE_TARGET_BRANCH="master"
LOTTIE_DIR="${START_DIR}/rlottie"

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

#Bullet
if [ $BUILD_BULLET = true ]; then
    echo "building bullet"

    git clone --branch ${BULLET_TARGET_BRANCH} https://github.com/bulletphysics/bullet3.git ${BULLET_DIR}
    cd ${BULLET_DIR}
    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}
    cmake ${CMAKE_BUILD_SETTINGS} -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/bullet3 ../..
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
    cmake ${CMAKE_BUILD_SETTINGS} -DENTITYX_BUILD_TESTING=False -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/entityx ../..
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

    #Workaround for an issue in the sds dependency build noticed on arch linux.
    #There's probably a compiler flag fix for this but I don't know it :)
    cd Dependencies/sds_library
    git apply ${SCRIPT_DIR}/sds_patch.diff
    cd ..
    mkdir ${INSTALL_DIR}/sds_library
    cp -r sds_library/include ${INSTALL_DIR}/sds_library
    cd ${COLIBRI_DIR}
    git apply ${SCRIPT_DIR}/colibriVisibility.diff

    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}
    #Force c++11 to solve some problems with bleeding edge compilers.
    cmake ${CMAKE_BUILD_SETTINGS} -DOGRE_SOURCE=${OGRE_DIR} -DOGRE_BINARIES=${OGRE_BIN_DIR} -DCOLIBRIGUI_LIB_ONLY=TRUE -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/colibri -DCOLIBRIGUI_FLEXIBILITY_LEVEL=2 -DCMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS} -std=c++11" ../..
    make -j${NUM_THREADS} || exit 1

    INSTALL_BASE=${INSTALL_DIR}/colibri
    rm -rf ${INSTALL_BASE}
    mkdir ${INSTALL_BASE}
    mkdir -p ${INSTALL_BASE}/include
    cp -r ${COLIBRI_DIR}/include/ColibriGui ${INSTALL_BASE}/include/ColibriGui
    cp -r ${COLIBRI_DIR}/bin/Data ${INSTALL_BASE}/data
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

    git clone --branch ${SDL2_TARGET_BRANCH} https://github.com/libsdl-org/SDL.git ${SDL2_DIR}
    cd ${SDL2_DIR}
    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}
    cmake ${CMAKE_BUILD_SETTINGS} -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/SDL2 -DSDL_SHARED=FALSE -DSDL_PIPEWIRE=FALSE ../..
    make -j${NUM_THREADS} || exit 1
    make install
else
    echo "Skipping SDL2 build"
fi

#OpenALSoft
if [ $BUILD_OPENALSOFT = true ]; then
    echo "building OpenALSoft"

    git clone --branch ${OPENALSOFT_TARGET_BRANCH} https://github.com/kcat/openal-soft.git ${OPENALSOFT_DIR}
    cd ${OPENALSOFT_DIR}
    #For static builds to prevent it producing hidden symbols.
    git apply ${SCRIPT_DIR}/openALPatch.diff
    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}
    #Pipewire gave me issues on my archlinux setup.
    cmake ${CMAKE_BUILD_SETTINGS} -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/OpenALSoft -DALSOFT_BACKEND_PIPEWIRE=OFF -DALSOFT_BACKEND_SNDIO=OFF -DLIBTYPE=STATIC ../..
    make -j${NUM_THREADS} || exit 1
    make install

    #libsndfile which is a dependency for audio.
    git clone --branch ${LIBSNDFILE_TARGET_BRANCH} https://github.com/libsndfile/libsndfile.git ${LIBSNDFILE_DIR}
    cd ${LIBSNDFILE_DIR}
    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}
    cmake ${CMAKE_BUILD_SETTINGS} -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/libsndfile -DENABLE_MPEG=False -DENABLE_EXTERNAL_LIBS=False ../..
    make -j${NUM_THREADS} || exit 1
    make install
else
    echo "Skipping OpenALSoft build"
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
else
    echo "Skipping nativefiledialog build"
fi

#lottie
if [ $BUILD_LOTTIE = true ]; then
    echo "building rlottie"

    git clone --branch ${LOTTIE_TARGET_BRANCH} https://github.com/Samsung/rlottie.git ${LOTTIE_DIR}
    cd ${LOTTIE_DIR}
    git apply ${SCRIPT_DIR}/../macBuild/lottiePatch.diff
    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}
    cmake ${CMAKE_BUILD_SETTINGS} -DCMAKE_POSITION_INDEPENDENT_CODE=True -DBUILD_SHARED_LIBS=False -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/rlottie -DLIB_INSTALL_DIR=${INSTALL_DIR}/rlottie ../..
    make -j${NUM_THREADS} || exit 1
    make install
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
git clone --branch v1.13.0 https://github.com/gabime/spdlog.git ${INSTALL_DIR}/spdlog
git clone https://github.com/leethomason/tinyxml2.git ${INSTALL_DIR}/tinyxml2
#git clone https://github.com/Tencent/rapidjson.git ${INSTALL_DIR}/rapidjson

#Copy in the rapidjson provided by ogre, not the latest cloned one.
mkdir -p ${INSTALL_DIR}/rapidjson/include
cp -r ${OGRE_DEPS_DIR}/build/${CMAKE_BUILD_TYPE}/ogredeps/include/rapidjson ${INSTALL_DIR}/rapidjson/include
