#!/bin/bash -x

#CMAKE_BUILD_TYPE="Debug"

START_DIR="$1"
if [ -v ${1} ]; then
    echo "Please provide path to the engine code."
    exit 1
fi

#cd ${1}

rm -rf outAppDir
mkdir -p outAppDir/usr/bin
cp -r Hlms essential avSetup.cfg outAppDir/usr/bin

#You have to add the extract-and-run while in the container
linuxdeploy --appimage-extract-and-run \
    --appdir outAppDir/ \
    -e av -e RenderSystem_GL3Plus.so \
    -i ${1}/setup/logo.svg -d ${1}/setup/entry.desktop --output appimage