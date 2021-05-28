#!/bin/bash -x

#Run this command with your pwd as the output build directory of the engine.

START_DIR="$1"
if [ -v ${1} ]; then
    echo "Please provide path to the engine code."
    exit 1
fi

#Check we're in the right directory.
if [ ! -f av ]; then
    echo "Missing engine executable in pwd."
    exit 1
fi

rm -rf outAppDir
mkdir -p outAppDir/usr/bin
cp -r Hlms essential avSetup.cfg outAppDir/usr/bin

#You have to add the extract-and-run while in the container
linuxdeploy --appimage-extract-and-run \
    --appdir outAppDir/ \
    -e av -e RenderSystem_GL3Plus.so -e Plugin_ParticleFX.so \
    -i ${1}/setup/logo.svg -d ${1}/setup/entry.desktop --output appimage
