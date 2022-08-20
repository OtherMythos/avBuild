#!/bin/bash

#Build the image.
docker build -t avbuild-android-image -f Dockerfile --platform linux/amd64 .
