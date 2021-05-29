@echo off
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
SET BUILD_GOOGLETEST=true

::Ogre
SET "OGRE_TARGET_BRANCH=v2-2"
SET "OGRE_DIR_NAME=ogre2"
SET "OGRE_DIR=%START_DIR%\%OGRE_DIR_NAME%"
SET "OGRE_BIN_DIR=%OGRE_DIR%\build\%CMAKE_BUILD_TYPE%"

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

SET "GOOGLETEST_DIR=%START_DIR%\googletest"

::Start
cd %START_DIR%

IF %BUILD_OGRE% equ true (
    echo "Building ogre."

    ::Clone
    git clone --branch %OGRE_TARGET_BRANCH% https://github.com/OGRECave/ogre-next %OGRE_DIR%
    cd %OGRE_DIR%
    git clone --recurse-submodules --shallow-submodules https://github.com/OGRECave/ogre-next-deps Dependencies

    ::Build dependencies first.
    cd Dependencies
    ::Work around to get rapidjson correctly installed
    robocopy "%OGRE_DIR%\Dependencies\src\rapidjson\include" "%OGRE_DIR%\Dependencies\src\rapidjson\rapidjson" /E
    mkdir "build\%CMAKE_BUILD_TYPE%"
    cd "build\%CMAKE_BUILD_TYPE%"
    cmake %CMAKE_BUILD_SETTINGS% -DOGREDEPS_INSTALL_DEV=FALSE ../..
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe" OGREDEPS.sln

    ::Build Ogre
    cd %OGRE_DIR%
    mkdir %OGRE_BIN_DIR%
    cd %OGRE_BIN_DIR%
    cmake -DOGRE_DEPENDENCIES_DIR=C:\build\ogre2\Dependencies\build\Debug\ogredeps -DCMAKE_BUILD_TYPE=Debug -DRapidjson_INCLUDE_DIR=C:\build\ogre2\Dependencies\src\rapidjson ..\..
    cmake -DOGRE_DEPENDENCIES_DIR=C:\build\ogre2\Dependencies\build\Debug\ogredeps -DCMAKE_BUILD_TYPE=Debug -DRapidjson_INCLUDE_DIR=C:\build\ogre2\Dependencies\src\rapidjson ..\..
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe" OGRE.sln

)

::Bullet
IF %BUILD_BULLET% equ true (
    echo "building bullet"

    git clone --branch %BULLET_TARGET_BRANCH% https://github.com/bulletphysics/bullet3.git %BULLET_DIR%
    cd %BULLET_DIR%
    mkdir "build\%CMAKE_BUILD_TYPE%"
    cd "build\%CMAKE_BUILD_TYPE%"
    cmake %CMAKE_BUILD_SETTINGS% ../..
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe" BULLET_PHYSICS.sln
)

::Squirrel
IF %BUILD_SQUIRREL% equ true (
    echo "building squirrel"

    git clone --branch %SQUIRREL_TARGET_BRANCH% https://github.com/albertodemichelis/squirrel.git %SQUIRREL_DIR%
    cd %SQUIRREL_DIR%
    mkdir "build\%CMAKE_BUILD_TYPE%"
    cd "build\%CMAKE_BUILD_TYPE%"
    cmake %CMAKE_BUILD_SETTINGS% ../..
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe" SQUIRREL.sln
)

::EntityX
IF %BUILD_ENTITYX% equ true (
    echo "building entityX"

    git clone --branch %ENTITYX_TARGET_BRANCH% https://github.com/alecthomas/entityx.git %ENTITYX_DIR%
    cd %ENTITYX_DIR%
    mkdir "build\%CMAKE_BUILD_TYPE%"
    cd "build\%CMAKE_BUILD_TYPE%"
    cmake %CMAKE_BUILD_SETTINGS% -DENTITYX_BUILD_TESTING=False -DENTITYX_BUILD_SHARED=False ../..
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe" ENTITYX.sln
)

::Colibri
IF %BUILD_COLIBRI% equ true (
    echo "building ColibriGUI"
    git clone --branch %COLIBRI_TARGET_BRANCH% https://github.com/darksylinc/colibrigui.git %COLIBRI_DIR%
    cd %COLIBRI_DIR%
    mkdir "build\%CMAKE_BUILD_TYPE%"

    ::Frustrating bodge I do to get colibri to see the rapidjson include
    mkdir "Dependencies\Ogre\Dependencies\include"
    robocopy "%OGRE_DIR%\Dependencies\src\rapidjson" "Dependencies\Ogre\Dependencies\include" /E
    cd "build\%CMAKE_BUILD_TYPE%"
    cmake %CMAKE_BUILD_SETTINGS% -DOGRE_SOURCE=%OGRE_DIR% -DOGRE_BINARIES=%OGRE_BIN_DIR% -DCOLIBRIGUI_LIB_ONLY=TRUE ../..
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe" ColibriGui.sln
)

::RecastDetour
IF %BUILD_DETOUR% equ true (
    echo "building RecastDetour"

    git clone --branch %DETOUR_TARGET_BRANCH% https://github.com/recastnavigation/recastnavigation.git %DETOUR_DIR%
    cd %DETOUR_DIR%
    mkdir "build\%CMAKE_BUILD_TYPE%"
    cd "build\%CMAKE_BUILD_TYPE%"
    cmake %CMAKE_BUILD_SETTINGS% -DRECASTNAVIGATION_DEMO=FALSE -DRECASTNAVIGATION_EXAMPLES=FALSE -DRECASTNAVIGATION_TESTS=FALSE ../..
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe" RecastNavigation.sln
)


::googletest
IF %BUILD_GOOGLETEST% equ true (
    echo "building googletest"

    git clone https://github.com/google/googletest.git %GOOGLETEST_DIR%
    cd %GOOGLETEST_DIR%
    mkdir "build\%CMAKE_BUILD_TYPE%"
    cd "build\%CMAKE_BUILD_TYPE%"
    cmake %CMAKE_BUILD_SETTINGS% ../..
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe" googletest-distribution.sln
)

::#Clone helper libs that don't directly need compiling.
cd %START_DIR%
git clone https://github.com/wjakob/filesystem.git
git clone https://github.com/gabime/spdlog.git
git clone https://github.com/leethomason/tinyxml2.git
git clone https://github.com/Tencent/rapidjson.git


exit 1

:NoPath
    echo "Please provide a build directory path."
exit 1