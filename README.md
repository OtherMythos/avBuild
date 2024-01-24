# avBuild

#### Tools to build dependencies for the avEngine
This repository is responsible for building the engine's dependencies into the ```avBuilt``` directory, a format the engine's build system expects to find.

The avBuilt directory can be compressed and distributed easily, allowing the dependencies to be made as lean as possible, helping build the engine quickly later on.

### Windows
```shell
mkdir ~/buildWindows
cd windowsBuild
./build.bat ~/buildWindows
```

### Linux
```shell
apt install cmake build-essential git
mkdir ~/buildLinux
cd linuxBuild
./build.sh ~/buildLinux
```

### MacOS
Ensure you have XCode installed along with the apple developer tools.
As well as this ensure cmake is installed and available on your path.
```shell
brew install cmake
mkdir ~/buildMac
cd macBuild
./build.sh ~/buildMac
```