::@echo off
SETLOCAL

SET "START_DIR=%1%"
SET "BUILD_TYPE=%2%"
echo %START_DIR%

IF "%~1" == "" GOTO NoPath

SET NUM_THREADS=4
SET "CMAKE_BUILD_TYPE=%BUILD_TYPE%"
SET "CMAKE_BUILD_SETTINGS=-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
:: Build settings
SET BUILD_OGRE=true
SET BUILD_BULLET=true
SET BUILD_SQUIRREL=true
SET BUILD_ENTITYX=true
SET BUILD_COLIBRI=true
SET BUILD_DETOUR=true
SET BUILD_SDL2=true
SET BUILD_OPENALSOFT=true
SET BUILD_NFD=true
SET BUILD_GOOGLETEST=true

SET "INSTALL_DIR=%START_DIR%\avBuilt\%CMAKE_BUILD_TYPE%"

::Ogre
SET "OGRE_TARGET_BRANCH=v2-3"
SET "OGRE_DIR_NAME=ogre2"
SET "OGRE_DIR=%START_DIR%\%OGRE_DIR_NAME%"
SET "OGRE_BIN_DIR=%OGRE_DIR%\build\%CMAKE_BUILD_TYPE%"
SET "OGRE_DEPS_DIR=%START_DIR%\ogre-next-deps"

::Bullet
SET "BULLET_TARGET_BRANCH=master"
SET "BULLET_DIR=%START_DIR%\bullet3"

::Squirrel
SET "SQUIRREL_TARGET_BRANCH=master"
SET "SQUIRREL_DIR=%START_DIR%\squirrel"

::EntityX
SET "ENTITYX_TARGET_BRANCH=master"
SET "ENTITYX_DIR=%START_DIR%\entityx"

::ColibriGUI
SET "COLIBRI_TARGET_BRANCH=flexibilityFix"
SET "COLIBRI_DIR=%START_DIR%\colibri"

::RecastDetour
SET "DETOUR_TARGET_BRANCH=main"
SET "DETOUR_DIR=%START_DIR%\recastdetour"

::SDL2
SET SDL2_TARGET_BRANCH="release-2.30.2"
SET SDL2_DIR="%START_DIR%\SDL2"

::OpenALSoft
SET "OPENALSOFT_TARGET_BRANCH=master"
SET "OPENALSOFT_DIR=%START_DIR%\OpenALSoft"
SET "LIBSNDFILE_TARGET_BRANCH=1.1.0"
SET "LIBSNDFILE_DIR=%START_DIR%\libsndfile"

::nativefiledialog
SET NFD_TARGET_BRANCH="master"
SET NFD_DIR="%START_DIR%\nativefiledialog"

SET GOOGLETEST_DIR="%START_DIR%\googletest"

::Start
cd %START_DIR%

IF %BUILD_OGRE% equ true (
    echo "Building ogre."

    ::Clone
    git clone --branch %OGRE_TARGET_BRANCH% https://github.com/OGRECave/ogre-next %OGRE_DIR%
    git clone --recurse-submodules --shallow-submodules https://github.com/OGRECave/ogre-next-deps %OGRE_DEPS_DIR%

    @REM TODO This should just be build/ as both release and Debug end up in the same location.
    ::Build dependencies first.
    cd %OGRE_DEPS_DIR%
    mkdir "build\Debug"
    cd "build\Debug"
    cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=11 ../..
    ::This performs both the build and install.
    ::Build both debug and release as this solves some Ogre find vulkan issues.
    cmake --build . --target install --config Debug
    cmake --build . --target install --config Release

    ::Build Ogre
    cd %OGRE_DIR%
    @REM NOTE: Remove the debug.
    ::Windows is really strict about who can create a symlink so unfortunately I have to duplicate the build over.
    robocopy "%OGRE_DEPS_DIR%/build/Debug/ogredeps" "%OGRE_DIR%/Dependencies" /E
    mkdir %OGRE_BIN_DIR%
    cd %OGRE_BIN_DIR%
    cmake %CMAKE_BUILD_SETTINGS% -DOGRE_BUILD_SAMPLES2=False -DCMAKE_INSTALL_PREFIX=%INSTALL_DIR%\ogre2 -DOGRE_DEPENDENCIES_DIR=%OGRE_DEPS_DIR%\build\%CMAKE_BUILD_TYPE%\ogredeps ..\..
    cmake --build . --target install
)

::Bullet
IF %BUILD_BULLET% equ true (
    echo "building bullet"

    git clone --branch %BULLET_TARGET_BRANCH% https://github.com/bulletphysics/bullet3.git %BULLET_DIR%
    cd %BULLET_DIR%
    mkdir "build\%CMAKE_BUILD_TYPE%"
    cd "build\%CMAKE_BUILD_TYPE%"
    cmake %CMAKE_BUILD_SETTINGS% -DCMAKE_INSTALL_PREFIX=%INSTALL_DIR%\bullet3 -DUSE_MSVC_RUNTIME_LIBRARY_DLL=True ../..
    cmake --build .
    @REM cmake --build . --target install
    ::Don't do the provided install for bullet. It had some weirdness.
    mkdir %INSTALL_DIR%\bullet3\include
    mkdir %INSTALL_DIR%\bullet3\lib
    robocopy .\lib\Debug\ %INSTALL_DIR%\bullet3\lib *.lib
    robocopy %BULLET_DIR%\src %INSTALL_DIR%\bullet3\include\bullet /S
)

::Squirrel
IF %BUILD_SQUIRREL% equ true (
    echo "building squirrel"

    git clone --branch %SQUIRREL_TARGET_BRANCH% https://github.com/albertodemichelis/squirrel.git %SQUIRREL_DIR%
    cd %SQUIRREL_DIR%
    mkdir "build\%CMAKE_BUILD_TYPE%"
    cd "build\%CMAKE_BUILD_TYPE%"
    cmake %CMAKE_BUILD_SETTINGS% -DCMAKE_INSTALL_PREFIX=%INSTALL_DIR%\squirrel ../..
    cmake --build .
    cmake --build . --target install
)

::EntityX
IF %BUILD_ENTITYX% equ true (
    echo "building entityX"

    git clone --branch %ENTITYX_TARGET_BRANCH% https://github.com/alecthomas/entityx.git %ENTITYX_DIR%
    cd %ENTITYX_DIR%
    mkdir "build\%CMAKE_BUILD_TYPE%"
    cd "build\%CMAKE_BUILD_TYPE%"
    cmake %CMAKE_BUILD_SETTINGS% -DENTITYX_BUILD_TESTING=False -DENTITYX_BUILD_SHARED=False -DCMAKE_INSTALL_PREFIX=%INSTALL_DIR%\entityx ../..
    cmake --build .
    cmake --build . --target install
)

::Colibri
IF %BUILD_COLIBRI% equ true (
    echo "building ColibriGUI"
    git clone --recurse-submodules --shallow-submodules --branch %COLIBRI_TARGET_BRANCH% https://github.com/edherbert/colibrigui.git %COLIBRI_DIR%
    cd %COLIBRI_DIR%
    mkdir "build\%CMAKE_BUILD_TYPE%"

    ::Frustrating bodge I do to get colibri to see the rapidjson include
    mkdir "Dependencies\Ogre\Dependencies\include"
    robocopy "%OGRE_DEPS_DIR%\src\rapidjson" "Dependencies\Ogre\Dependencies\include" /E
    move "Dependencies\Ogre\Dependencies\include\include" "Dependencies\Ogre\Dependencies\include\rapidjson"
    cd "build\%CMAKE_BUILD_TYPE%"
    cmake %CMAKE_BUILD_SETTINGS% -DOGRE_SOURCE=%OGRE_DIR% -DOGRE_BINARIES=%OGRE_BIN_DIR% -DCOLIBRIGUI_LIB_ONLY=TRUE -DCOLIBRIGUI_FLEXIBILITY_LEVEL=2 -DCMAKE_INSTALL_PREFIX=%INSTALL_DIR%\colibri ../..
    cmake --build .

    rmdir /S /Q "%INSTALL_DIR%/colibri"
    mkdir "%INSTALL_DIR%/colibri"
    mkdir "%INSTALL_DIR%/colibri/include"
    robocopy "%COLIBRI_DIR%/include/ColibriGui" "%INSTALL_DIR%/colibri/include/ColibriGui" /E
    robocopy "%COLIBRI_DIR%/bin/Data" "%INSTALL_DIR%/colibri/data" /E
    robocopy "%COLIBRI_DIR%/Dependencies" "%INSTALL_DIR%/colibri/dependencies" /E
    mkdir "%INSTALL_DIR%/colibri/lib64"
    mkdir "%INSTALL_DIR%/colibri/bin"
    for /R %COLIBRI_DIR% %%f in (*.lib) do copy %%f "%INSTALL_DIR%/colibri/lib64"
    for /R %COLIBRI_DIR% %%f in (*.dll) do copy %%f "%INSTALL_DIR%/colibri/bin"
)

::RecastDetour
IF %BUILD_DETOUR% equ true (
    echo "building RecastDetour"

    git clone --branch %DETOUR_TARGET_BRANCH% https://github.com/recastnavigation/recastnavigation.git %DETOUR_DIR%
    cd %DETOUR_DIR%
    mkdir "build\%CMAKE_BUILD_TYPE%"
    cd "build\%CMAKE_BUILD_TYPE%"
    cmake %CMAKE_BUILD_SETTINGS% -DRECASTNAVIGATION_DEMO=FALSE -DRECASTNAVIGATION_EXAMPLES=FALSE -DRECASTNAVIGATION_TESTS=FALSE -DCMAKE_INSTALL_PREFIX=%INSTALL_DIR%\recastdetour ../..
    cmake --build .
    cmake --build . --target install
)

::OpenALSoft
IF %BUILD_OPENALSOFT% equ true (
    echo "building OpenALSoft"

    git clone --branch %OPENALSOFT_TARGET_BRANCH% https://github.com/kcat/openal-soft.git %OPENALSOFT_DIR%
    cd %OPENALSOFT_DIR%
    mkdir "build\%CMAKE_BUILD_TYPE%"
    cd "build\%CMAKE_BUILD_TYPE%"
    cmake %CMAKE_BUILD_SETTINGS% -DCMAKE_INSTALL_PREFIX=%INSTALL_DIR%/OpenALSoft -DLIBTYPE=STATIC ../..
    cmake --build .
    cmake --build . --target install

    ::libsndfile which is a dependency for audio.
    git clone --branch %LIBSNDFILE_TARGET_BRANCH% https://github.com/libsndfile/libsndfile.git %LIBSNDFILE_DIR%
    cd %LIBSNDFILE_DIR%
    mkdir "build/%CMAKE_BUILD_TYPE%"
    cd "build/%CMAKE_BUILD_TYPE%"
    cmake %CMAKE_BUILD_SETTINGS% -DCMAKE_INSTALL_PREFIX=%INSTALL_DIR%/libsndfile -DENABLE_MPEG=False -DENABLE_EXTERNAL_LIBS=False ../..
    cmake --build .
    cmake --build . --target install
)

::nativefiledialog
IF %BUILD_NFD% equ true (
    echo "building nativefiledialog"

    git clone --branch %NFD_TARGET_BRANCH% https://github.com/btzy/nativefiledialog-extended.git %NFD_DIR%
    cd %NFD_DIR%
    mkdir "build/%CMAKE_BUILD_TYPE%"
    cd "build/%CMAKE_BUILD_TYPE%"
    cmake %CMAKE_BUILD_SETTINGS% -DCMAKE_INSTALL_PREFIX=%INSTALL_DIR%/nativefiledialog ../..
    cmake --build .
    cmake --build . --target install
)

::googletest
IF %BUILD_GOOGLETEST% equ true (
    echo "building googletest"

    git clone https://github.com/google/googletest.git %GOOGLETEST_DIR%
    cd %GOOGLETEST_DIR%
    mkdir "build\%CMAKE_BUILD_TYPE%"
    cd "build\%CMAKE_BUILD_TYPE%"
    cmake %CMAKE_BUILD_SETTINGS% -DCMAKE_INSTALL_PREFIX=%INSTALL_DIR%\googletest ../..
    cmake --build .
    cmake --build . --target install
)

cd %INSTALL_DIR%

::SDL2
IF %BUILD_SDL2% equ true (
    echo "building SDL2"

    git clone --branch %SDL2_TARGET_BRANCH% https://github.com/libsdl-org/SDL.git %SDL2_DIR%
    cd %SDL2_DIR%
    mkdir "build/%CMAKE_BUILD_TYPE%"
    cd "build/%CMAKE_BUILD_TYPE%"
    cmake %CMAKE_BUILD_SETTINGS% -DCMAKE_INSTALL_PREFIX=%INSTALL_DIR%/SDL2 ../..
    cmake --build .
    cmake --build . --target install
)

::#Clone helper libs that don't directly need compiling.
git clone https://github.com/wjakob/filesystem.git %INSTALL_DIR%\filesystem
git clone https://github.com/gabime/spdlog.git %INSTALL_DIR%\spdlog
git clone https://github.com/leethomason/tinyxml2.git %INSTALL_DIR%\tinyxml2

::Copy in the rapidjson provided by ogre, not the latest cloned one.
mkdir %INSTALL_DIR%\rapidjson\include\rapidjson
robocopy %OGRE_DEPS_DIR%\build\%CMAKE_BUILD_TYPE%\ogredeps\include\rapidjson %INSTALL_DIR%\rapidjson\include\rapidjson /E

exit 0

:NoPath
    echo "Please provide a build directory path."
exit 0
