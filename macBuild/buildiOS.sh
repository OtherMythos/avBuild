#!/bin/bash -x

CMAKE_EXEC="cmake"

START_DIR="$1"
if [ -v ${1} ]; then
    echo "Please provide a build directory path."
    exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

CMAKE_BUILD_TYPE="Debug"
if [ ${2+x} ]; then
    CMAKE_BUILD_TYPE=${2}
    echo "Build type set to '${2}'"
fi
BUILD_IOS=true

CMAKE_BUILD_SETTINGS="-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} -G Xcode"

if [ $BUILD_IOS = true ]; then
    echo "Building for ios"
    CMAKE_BUILD_SETTINGS="${CMAKE_BUILD_SETTINGS} -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0"
else
    echo "Building for macos"
    CMAKE_BUILD_SETTINGS="${CMAKE_BUILD_SETTINGS} -DCMAKE_OSX_ARCHITECTURES=x86_64"
fi

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
    cd ${OGRE_DIR}
    git clone --recurse-submodules --shallow-submodules https://github.com/OGRECave/ogre-next-deps ${OGRE_DEPS_DIR}

    #Build dependencies first.
    cd ${OGRE_DEPS_DIR}
    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}
    #Force c++11 because freeimage seems broken in places.
    ${CMAKE_EXEC} ${CMAKE_BUILD_SETTINGS} -DOGRE_SIMD_SSE2=0 -DOGRE_BUILD_PLATFORM_APPLE_IOS=1 -DOGREDEPS_BUILD_SHADERC=False -DOGREDEPS_BUILD_REMOTERY=False -DOGREDEPS_BUILD_OPENVR=False -DOGRE_UNITY_BUILD=1 -D OGRE_SIMD_NEON=0 -DOGRE_USE_BOOST=0 -D OGRE_CONFIG_THREAD_PROVIDER=0 -DOGRE_CONFIG_THREADS=0 -DCMAKE_CXX_STANDARD=11 ../..
    xcodebuild -scheme ALL_BUILD -project OGREDEPS.xcodeproj -destination generic/platform=iOS
    xcodebuild -scheme install -project OGREDEPS.xcodeproj -destination generic/platform=iOS

    #Build Ogre
    cd ${OGRE_DIR}
    ln -s ${OGRE_DEPS_DIR}/build/${CMAKE_BUILD_TYPE}/ogredeps iOSDependencies
    #This material breaks the samples when using metal.
    mv ${OGRE_DIR}/Samples/Media/2.0/scripts/materials/Common/HiddenAreaMeshVr.material ${OGRE_DIR}/Samples/Media/2.0/scripts/materials/Common/HiddenAreaMeshVr.materialll
    mv ${OGRE_DIR}/Samples/Media/2.0/scripts/materials/Common/RadialDensityMask.material ${OGRE_DIR}/Samples/Media/2.0/scripts/materials/Common/RadialDensityMask.materiallll

    mkdir -p ${OGRE_BIN_DIR}
    cd ${OGRE_BIN_DIR}

    #cmake ${CMAKE_BUILD_SETTINGS} \
    #-DCMAKE_CXX_FLAGS="-I/usr/local/include -F/Library/Frameworks" \
    ${CMAKE_EXEC} -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} -G Xcode \
    -DOGRE_BUILD_PLATFORM_APPLE_IOS=1 -DOGRE_SIMD_SSE2=0 -DOGRE_BUILD_SAMPLES2=False \
    -DOGRE_BUILD_RENDERSYSTEM_METAL=1 -DOGRE_USE_BOOST=0 -DOGRE_CONFIG_THREAD_PROVIDER=0 -DOGRE_CONFIG_THREADS=0 -DOGRE_UNITY_BUILD=0 -DOGRE_SIMD_NEON=0 -DOGRE_BUILD_TESTS=0 \
    -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/ogre2 -DCMAKE_CXX_STANDARD=11 -DOGRE_BUILD_RENDERSYSTEM_GL3PLUS=OFF ../..
    #Slight hack to remove some macOS frameworks the cmake function was adding.
    sed -i '' '/FRAMEWORK_SEARCH_PATHS/d' OGRE-Next.xcodeproj/project.pbxproj
    xcodebuild -scheme ALL_BUILD -project OGRE-Next.xcodeproj -destination generic/platform=iOS

    #Sooo it seems install is broken when building for ios.
    #So I work around it with this. Slightly hacky unfortunately.
    rm -rf ${INSTALL_DIR}/ogre2
    mkdir ${INSTALL_DIR}/ogre2
    cp -r ${OGRE_DIR}/Samples/Media ${INSTALL_DIR}/ogre2
    mkdir -p ${INSTALL_DIR}/ogre2/include/OGRE
    cp -r ${OGRE_DIR}/OgreMain/include/* ${INSTALL_DIR}/ogre2/include/OGRE
    cp ${OGRE_DIR}/build/${CMAKE_BUILD_TYPE}/include/* ${INSTALL_DIR}/ogre2/include/OGRE
    mkdir -p ${INSTALL_DIR}/ogre2/lib/${CMAKE_BUILD_TYPE}
    find ${OGRE_DIR}/build/${CMAKE_BUILD_TYPE}/lib/iphoneos -name "*.a" -type f -exec cp {} ${INSTALL_DIR}/ogre2/lib/${CMAKE_BUILD_TYPE} \;

    mkdir -p ${INSTALL_DIR}/ogre2/include/OGRE/Hlms/Pbs
    mkdir -p ${INSTALL_DIR}/ogre2/include/OGRE/Hlms/Common
    mkdir -p ${INSTALL_DIR}/ogre2/include/OGRE/Hlms/Unlit
    cp -r ${OGRE_DIR}/Components/Hlms/Common/include/* ${INSTALL_DIR}/ogre2/include/OGRE/Hlms/Common
    cp -r ${OGRE_DIR}/Components/Hlms/Pbs/include/* ${INSTALL_DIR}/ogre2/include/OGRE/Hlms/Pbs
    cp -r ${OGRE_DIR}/Components/Hlms/Unlit/include/* ${INSTALL_DIR}/ogre2/include/OGRE/Hlms/Unlit
    mkdir -p ${INSTALL_DIR}/ogre2/include/OGRE/RenderSystems/Metal
    cp -r ${OGRE_DIR}/RenderSystems/Metal/include/* ${INSTALL_DIR}/ogre2/include/OGRE/RenderSystems/Metal
    mkdir -p ${INSTALL_DIR}/ogre2/include/OGRE/Plugins/ParticleFX
    cp -r ${OGRE_DIR}/PlugIns/ParticleFX/include/* ${INSTALL_DIR}/ogre2/include/OGRE/Plugins/ParticleFX

    cp -r ${OGRE_DIR}/iOSDependencies/ ${INSTALL_DIR}/ogre2/iOSDependencies
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
    ${CMAKE_EXEC} ${CMAKE_BUILD_SETTINGS} -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/bullet3 -DINSTALL_LIBS=True \
        -DBUILD_BULLET_ROBOTICS_EXTRA=False -DBUILD_BULLET_ROBOTICS_GUI_EXTRA=False -DBUILD_BULLET2_DEMOS=False -DBUILD_CPU_DEMOS=False -DBUILD_OPENGL3_DEMOS=False -DBUILD_UNIT_TESTS=False -DBUILD_EXTRAS=False ../..
    xcodebuild -scheme ALL_BUILD -project BULLET_PHYSICS.xcodeproj -destination generic/platform=iOS
    xcodebuild -scheme install -project BULLET_PHYSICS.xcodeproj -destination generic/platform=iOS
    # -destination generic/platform=ios
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
    ${CMAKE_EXEC} ${CMAKE_BUILD_SETTINGS} -DDISABLE_DYNAMIC=True -DSQ_DISABLE_INTERPRETER=True -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/squirrel -DCMAKE_CXX_FLAGS="-DIOS" ../..

    xcodebuild -scheme ALL_BUILD -project squirrel.xcodeproj -destination generic/platform=iOS
    xcodebuild -scheme install -project squirrel.xcodeproj -destination generic/platform=iOS
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
    ${CMAKE_EXEC} ${CMAKE_BUILD_SETTINGS} -DENTITYX_BUILD_TESTING=False -DENTITYX_BUILD_SHARED=False -DENTITYX_BUILD_TESTING=False -DENTITYX_RUN_BENCHMARKS=False -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/entityx ../..
    xcodebuild -scheme ALL_BUILD -project EntityX.xcodeproj -destination generic/platform=iOS
    xcodebuild -scheme install -project EntityX.xcodeproj -destination generic/platform=iOS
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
    git apply ${SCRIPT_DIR}/iosSdsDiff.diff
    cd ..
    mkdir ${INSTALL_DIR}/sds_library
    cp -r sds_library/include ${INSTALL_DIR}/sds_library
    cd ${COLIBRI_DIR}

    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}
    #Force c++11 to solve some problems with bleeding edge compilers.
    ${CMAKE_EXEC} ${CMAKE_BUILD_SETTINGS} -DOGRE_SOURCE=${OGRE_DIR} -DOGRE_BINARIES=${OGRE_BIN_DIR} -DAPPLE_IOS=TRUE -DCOLIBRIGUI_LIB_ONLY=TRUE -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/colibri -DCOLIBRIGUI_FLEXIBILITY_LEVEL=2 -DCMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS} -std=c++11" ../..
    #Don't build ALL_BUILD as it tries to build a shared zlib which is an issue in ios.
    xcodebuild -scheme ColibriGui -project ColibriGui.xcodeproj -destination generic/platform=iOS

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
    ${CMAKE_EXEC} ${CMAKE_BUILD_SETTINGS} -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/recastdetour -DRECASTNAVIGATION_DEMO=FALSE -DRECASTNAVIGATION_EXAMPLES=FALSE -DRECASTNAVIGATION_TESTS=FALSE ../..
    xcodebuild -scheme ALL_BUILD -project RecastNavigation.xcodeproj -destination generic/platform=iOS
    xcodebuild -scheme install -project RecastNavigation.xcodeproj -destination generic/platform=iOS
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
    git apply ${SCRIPT_DIR}/iosDiff.diff
    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}

    ${CMAKE_EXEC} ${CMAKE_BUILD_SETTINGS} -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/SDL2 -DSDL_SHARED=FALSE ../..
    xcodebuild -scheme ALL_BUILD -project SDL2.xcodeproj -destination generic/platform=iOS
    xcodebuild -scheme install -project SDL2.xcodeproj -destination generic/platform=iOS
    #cp -r ${SDL2_DIR}/src/main/ ${INSTALL_DIR}/SDL2/main/
    cp -r ${SDL2_DIR}/src/ ${INSTALL_DIR}/SDL2/src
else
    echo "Skipping SDL2 build"
fi

#OpenALSoft
if [ $BUILD_OPENALSOFT = true ]; then
    echo "building OpenALSoft"

    git clone --branch ${OPENALSOFT_TARGET_BRANCH} https://github.com/kcat/openal-soft.git ${OPENALSOFT_DIR}
    cd ${OPENALSOFT_DIR}
    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}
    ${CMAKE_EXEC} ${CMAKE_BUILD_SETTINGS} -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/OpenALSoft -DLIBTYPE=STATIC -DALSOFT_EXAMPLES=False -DALSOFT_UTILS=False ../..
    xcodebuild -scheme ALL_BUILD -project OpenAL.xcodeproj -destination generic/platform=iOS
    xcodebuild -scheme install -project OpenAL.xcodeproj -destination generic/platform=iOS

    #libsndfile which is a dependency for audio.
    git clone --branch ${LIBSNDFILE_TARGET_BRANCH} https://github.com/libsndfile/libsndfile.git ${LIBSNDFILE_DIR}
    cd ${LIBSNDFILE_DIR}
    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}
    ${CMAKE_EXEC} ${CMAKE_BUILD_SETTINGS} -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/libsndfile -DBUILD_PROGRAMS=OFF -DBUILD_EXAMPLES=OFF -DBUILD_TESTING=OFF -DENABLE_EXTERNAL_LIBS=False ../..
    xcodebuild -scheme sndfile -project libsndfile.xcodeproj -destination generic/platform=iOS
    xcodebuild -scheme install -project libsndfile.xcodeproj -destination generic/platform=iOS
else
    echo "Skipping OpenALSoft build"
fi

#lottie
if [ $BUILD_LOTTIE = true ]; then
    echo "building rlottie"

    git clone --branch ${LOTTIE_TARGET_BRANCH} https://github.com/Samsung/rlottie.git ${LOTTIE_DIR}
    cd ${LOTTIE_DIR}
    git apply ${SCRIPT_DIR}/lottiePatch.diff
    sed -i '' '/add_subdirectory(example)/d' CMakeLists.txt
    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}
    ${CMAKE_EXEC} ${CMAKE_BUILD_SETTINGS} -DBUILD_SHARED_LIBS=False -DLOTTIE_MODULE=False -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/rlottie -DLIB_INSTALL_DIR=${INSTALL_DIR}/rlottie ../..
    xcodebuild -scheme ALL_BUILD -project rlottie.xcodeproj -destination generic/platform=iOS
    xcodebuild -scheme install -project rlottie.xcodeproj -destination generic/platform=iOS
else
    echo "Skipping nativefiledialog build"
fi

#googletest
    echo "building googletest"

    git clone https://github.com/google/googletest.git ${GOOGLETEST_DIR}
    cd ${GOOGLETEST_DIR}
    mkdir -p build/${CMAKE_BUILD_TYPE}
    cd build/${CMAKE_BUILD_TYPE}
    ${CMAKE_EXEC} ${CMAKE_BUILD_SETTINGS} -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/googletest ../..
    xcodebuild -scheme ALL_BUILD -project googletest-distribution.xcodeproj -destination generic/platform=iOS
    xcodebuild -scheme install -project googletest-distribution.xcodeproj -destination generic/platform=iOS

#Clone helper libs that don't directly need compiling.
cd ${START_DIR}
git clone https://github.com/wjakob/filesystem.git ${INSTALL_DIR}/filesystem
git clone --branch v1.13.0 https://github.com/gabime/spdlog.git ${INSTALL_DIR}/spdlog
git clone https://github.com/leethomason/tinyxml2.git ${INSTALL_DIR}/tinyxml2
#git clone https://github.com/Tencent/rapidjson.git ${INSTALL_DIR}/rapidjson

#Copy in the rapidjson provided by ogre, not the latest cloned one.
mkdir -p ${INSTALL_DIR}/rapidjson/include
cp -r ${OGRE_DEPS_DIR}/build/${CMAKE_BUILD_TYPE}/ogredeps/include/rapidjson ${INSTALL_DIR}/rapidjson/include
