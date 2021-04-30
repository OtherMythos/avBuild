#!/bin/bash

#Variables
START_DIR="/avbuild/build"
NUM_THREADS=4
#Ogre
OGRE_TARGET_BRANCH="v2-2"
OGRE_DIR="${START_DIR}/ogre2"

#Start
cd ${START_DIR}

#Ogre
#Clone
git clone --branch ${OGRE_TARGET_BRANCH} https://github.com/OGRECave/ogre-next ${OGRE_DIR}
cd ${OGRE_DIR}
git clone --recurse-submodules --shallow-submodules https://github.com/OGRECave/ogre-next-deps Dependencies

# #Build dependencies first.
cd Dependencies
mkdir build
cd build
cmake ..
make -j${NUM_THREADS}
make install

#Build Ogre
cd ${OGRE_DIR}
mkdir build
cd build
cmake ..
make -j${NUM_THREADS}
