::@echo off
SETLOCAL

SET "START_DIR=%1%"
echo %START_DIR%

IF "%~1" == "" GOTO NoPath

SET NUM_THREADS=4
SET "CMAKE_BUILD_TYPE=Debug"
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
SET "COLIBRI_TARGET_BRANCH=master"
SET "COLIBRI_DIR=%START_DIR%\colibri"

::RecastDetour
SET "DETOUR_TARGET_BRANCH=master"
SET "DETOUR_DIR=%START_DIR%\recastdetour"

::SDL2
SET SDL2_TARGET_BRANCH="release-2.0.14"
SET SDL2_DIR="%START_DIR%/SDL2"

::OpenALSoft
SET OPENALSOFT_TARGET_BRANCH="master"
SET OPENALSOFT_DIR="%START_DIR%/OpenALSoft"

::nativefiledialog
SET NFD_TARGET_BRANCH="master"
SET NFD_DIR="%START_DIR%/nativefiledialog"

SET GOOGLETEST_DIR="%START_DIR%/googletest"

::Start
cd %START_DIR%

IF %BUILD_OGRE% equ true (
    echo "Building ogre."

    ::Clone
    git clone --branch %OGRE_TARGET_BRANCH% https://github.com/OGRECave/ogre-next %OGRE_DIR%
    git clone --recurse-submodules --shallow-submodules https://github.com/OGRECave/ogre-next-deps %OGRE_DEPS_DIR%

    ::Build dependencies first.
    cd %OGRE_DEPS_DIR%
    mkdir "build\Debug"
    cd "build\Debug"
    cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=11 ../..
    ::This performs both the build and install.
    ::Build both debug and release as this solves some Ogre find vulkan issues.
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe" INSTALL.vcxproj /p:Configuration=Debug
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe" INSTALL.vcxproj /p:Configuration=Release

    ::Build Ogre
    cd %OGRE_DIR%
    mkdir %OGRE_BIN_DIR%
    cd %OGRE_BIN_DIR%
    cmake %CMAKE_BUILD_SETTINGS% -DCMAKE_INSTALL_PREFIX=%INSTALL_DIR%\ogre2 -DOGRE_DEPENDENCIES_DIR=%OGRE_DEPS_DIR%\build\%CMAKE_BUILD_TYPE%\ogredeps ..\..
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe" INSTALL.vcxproj
)

::Bullet
IF %BUILD_BULLET% equ true (
    echo "building bullet"

    git clone --branch %BULLET_TARGET_BRANCH% https://github.com/bulletphysics/bullet3.git %BULLET_DIR%
    cd %BULLET_DIR%
    mkdir "build\%CMAKE_BUILD_TYPE%"
    cd "build\%CMAKE_BUILD_TYPE%"
    cmake %CMAKE_BUILD_SETTINGS% -DCMAKE_INSTALL_PREFIX=%INSTALL_DIR%\bullet3 -DUSE_MSVC_RUNTIME_LIBRARY_DLL=True ../..
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe" BULLET_PHYSICS.sln
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
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe" INSTALL.vcxproj
)

::EntityX
IF %BUILD_ENTITYX% equ true (
    echo "building entityX"

    git clone --branch %ENTITYX_TARGET_BRANCH% https://github.com/alecthomas/entityx.git %ENTITYX_DIR%
    cd %ENTITYX_DIR%
    mkdir "build\%CMAKE_BUILD_TYPE%"
    cd "build\%CMAKE_BUILD_TYPE%"
    cmake %CMAKE_BUILD_SETTINGS% -DENTITYX_BUILD_TESTING=False -DENTITYX_BUILD_SHARED=False -DCMAKE_INSTALL_PREFIX=%INSTALL_DIR%\entityx ../..
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe" INSTALL.vcxproj
)

::Colibri
IF %BUILD_COLIBRI% equ true (
    echo "building ColibriGUI"
    git clone --recurse-submodules --shallow-submodules --branch %COLIBRI_TARGET_BRANCH% https://github.com/darksylinc/colibrigui.git %COLIBRI_DIR%
    cd %COLIBRI_DIR%
    mkdir "build\%CMAKE_BUILD_TYPE%"

    ::Frustrating bodge I do to get colibri to see the rapidjson include
    mkdir "Dependencies\Ogre\Dependencies\include"
    robocopy "%OGRE_DEPS_DIR%\src\rapidjson" "Dependencies\Ogre\Dependencies\include" /E
    move "Dependencies\Ogre\Dependencies\include\include" "Dependencies\Ogre\Dependencies\include\rapidjson"
    cd "build\%CMAKE_BUILD_TYPE%"
    cmake %CMAKE_BUILD_SETTINGS% -DOGRE_SOURCE=%OGRE_DIR% -DOGRE_BINARIES=%OGRE_BIN_DIR% -DCOLIBRIGUI_LIB_ONLY=TRUE -DCMAKE_INSTALL_PREFIX=%INSTALL_DIR%\colibri ../..
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe" ALL_BUILD.vcxproj

    rmdir /S /Q "%INSTALL_DIR%/colibri"
    mkdir "%INSTALL_DIR%/colibri"
    mkdir "%INSTALL_DIR%/colibri/include"
    robocopy "%COLIBRI_DIR%/include/ColibriGui" "%INSTALL_DIR%/colibri/include/ColibriGui" /E
    robocopy "%COLIBRI_DIR%/bin/Data" "%INSTALL_DIR%/colibri/data" /E
    robocopy "%COLIBRI_DIR%/Dependencies" "%INSTALL_DIR%/colibri/dependencies" /E
    mkdir "%INSTALL_DIR%/colibri/lib64"
    for /R %COLIBRI_DIR% %%f in (*.lib) do copy %%f "%INSTALL_DIR%/colibri/lib64"
)

::RecastDetour
IF %BUILD_DETOUR% equ true (
    echo "building RecastDetour"

    git clone --branch %DETOUR_TARGET_BRANCH% https://github.com/recastnavigation/recastnavigation.git %DETOUR_DIR%
    cd %DETOUR_DIR%
    mkdir "build\%CMAKE_BUILD_TYPE%"
    cd "build\%CMAKE_BUILD_TYPE%"
    cmake %CMAKE_BUILD_SETTINGS% -DRECASTNAVIGATION_DEMO=FALSE -DRECASTNAVIGATION_EXAMPLES=FALSE -DRECASTNAVIGATION_TESTS=FALSE -DCMAKE_INSTALL_PREFIX=%INSTALL_DIR%\recastdetour ../..
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe" INSTALL.vcxproj
)

::OpenALSoft
IF %BUILD_OPENALSOFT% equ true (
    echo "building OpenALSoft"

    git clone --branch %OPENALSOFT_TARGET_BRANCH% https://github.com/kcat/openal-soft.git %OPENALSOFT_DIR%
    cd %OPENALSOFT_DIR%
    git checkout dc83d99c95a42c960150ddeee06c124134b52208
    mkdir "build\%CMAKE_BUILD_TYPE%"
    cd "build\%CMAKE_BUILD_TYPE%"
    cmake %CMAKE_BUILD_SETTINGS% -DCMAKE_INSTALL_PREFIX=%INSTALL_DIR%/OpenALSoft -DLIBTYPE=STATIC ../..
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe" INSTALL.vcxproj
)

::nativefiledialog
IF %BUILD_NFD% equ true (
    echo "building nativefiledialog"

    git clone --branch %NFD_TARGET_BRANCH% https://github.com/btzy/nativefiledialog-extended.git %NFD_DIR%
    cd %NFD_DIR%
    mkdir "build/%CMAKE_BUILD_TYPE%"
    cd "build/%CMAKE_BUILD_TYPE%"
    cmake %CMAKE_BUILD_SETTINGS% -DCMAKE_INSTALL_PREFIX=%INSTALL_DIR%/nativefiledialog ../..
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe" INSTALL.vcxproj
)

::googletest
IF %BUILD_GOOGLETEST% equ true (
    echo "building googletest"

    git clone https://github.com/google/googletest.git %GOOGLETEST_DIR%
    cd %GOOGLETEST_DIR%
    mkdir "build\%CMAKE_BUILD_TYPE%"
    cd "build\%CMAKE_BUILD_TYPE%"
    cmake %CMAKE_BUILD_SETTINGS% -DCMAKE_INSTALL_PREFIX=%INSTALL_DIR%\googletest ../..
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe" INSTALL.vcxproj
)

cd %INSTALL_DIR%

::Get SDL2 as the built binary on Windows. It's hosted on Mercurial which made it difficult.
rmdir /S /Q SDL2 SDL2-2.0.14
curl --url https://www.libsdl.org/release/SDL2-devel-2.0.14-VC.zip --output "%INSTALL_DIR%\sdl2.zip"
tar -xf sdl2.zip
del sdl2.zip
ren SDL2-2.0.14 SDL2

::#Clone helper libs that don't directly need compiling.
git clone https://github.com/wjakob/filesystem.git %INSTALL_DIR%\filesystem
git clone https://github.com/gabime/spdlog.git %INSTALL_DIR%\spdlog
git clone https://github.com/leethomason/tinyxml2.git %INSTALL_DIR%\tinyxml2

::Copy in the rapidjson provided by ogre, not the latest cloned one.
mkdir %INSTALL_DIR%/rapidjson/include
robocopy %OGRE_DEPS_DIR%/build/%CMAKE_BUILD_TYPE%/ogredeps/include/rapidjson %INSTALL_DIR%/rapidjson/include


exit 1

:NoPath
    echo "Please provide a build directory path."
exit 1
