# avBuild

#### Tools to build the avEngine and its dependencies
Convenient automation for building the avEngine's dependencies.

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