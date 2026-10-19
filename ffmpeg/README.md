# FFmpeg recording dependency

Static FFmpeg and OpenH264 libraries for desktop avEngine recording. Requires Python 3.9+,
CMake 3.20+, GNU Make, pkg-config/pkgconf, a C/C++ compiler and NASM on x86_64.

```sh
python3 ffmpeg/build.py ~/build --config Debug --verify
python3 ffmpeg/build.py ~/build --config Release --verify
# Rerun the encoding check against installed libraries:
python3 ffmpeg/build.py ~/build --config Debug --verify-only
# macOS can also build the other desktop architecture:
python3 ffmpeg/build.py ~/buildIntel --arch x86_64 --config Release --verify
```

The macOS, Linux and Windows dependency scripts call this builder. iOS and Android do not.
Use a build root without whitespace; the upstream make builds require it. macOS supports
arm64 and x86_64; Linux and Windows currently support x86_64. Verification must run on a
machine able to execute the selected architecture.
The desktop scripts verify native builds automatically; the macOS script skips execution
when building another architecture. Run `--verify-only` on a compatible machine afterwards.

On macOS install `cmake pkgconf` with Homebrew, plus `nasm` for Intel builds. On Linux,
install `build-essential cmake nasm pkg-config python3`. Windows uses Visual Studio 2022
C++ build tools, native Python/CMake/Ninja, and MSYS2 for configure/make:

```sh
# In the MSYS2 shell, once:
pacman -S --needed make nasm pkgconf
```

```bat
python ffmpeg\build.py C:\build --config Debug --msys-root C:\msys64 --verify
```

The builder finds Visual Studio via vswhere if no developer prompt is active. Set
`AV_MSYS_ROOT` or pass `--msys-root` for an alternative MSYS2 installation. FFmpeg and
OpenH264 both use `/MDd` in Debug and `/MD` otherwise, matching avEngine. MSYS2 is only a
build tool; the resulting program does not depend on its runtime.

Windows FFmpeg Debug builds retain symbols and the debug CRT, with `/O1` enabled:
MSVC `/Od` leaves unresolved references in disabled FFmpeg feature branches. OpenH264
and the verification program use their usual debug optimisation settings.
Linux FFmpeg disables x86 assembly because its H.264 decoder emits relocations
that cannot link into avEngine's shared `avCore.so`, even with `--enable-pic`.

## Installed package

`avBuilt/<configuration>/ffmpeg` contains static libraries, headers and a relocatable
CMake package:

```cmake
find_package(AVFFmpeg CONFIG REQUIRED
    PATHS "${AV_LIBS_DIR}/ffmpeg/lib/cmake/AVFFmpeg" NO_DEFAULT_PATH)
target_link_libraries(av PRIVATE AVFFmpeg::FFmpeg)
```

Consumers must enable C++ (OpenH264 uses it). The target includes static transitive and
platform dependencies. Runtime FFmpeg executables, DLLs and dylibs are unnecessary.

FFmpeg 9.0.2 and OpenH264 2.6.0 source archives are pinned by SHA256. Source/build directories
are separate by platform, architecture and configuration. Repeat commands reuse compilation
outputs. When changing the builder's compiler flags, remove that configuration's
`ffmpeg-build/<platform>-<arch>/<configuration>` directory before rebuilding.

Enabled capabilities: OpenH264 H.264 encoding, AAC encoding, MP4 muxing, file I/O, pixel
conversion/scaling and audio resampling. macOS also enables VideoToolbox H.264 encoding.
Native H.264/AAC decoders and MP4 demuxing let the standalone check validate its own output.
Other codecs, network I/O, devices, filters and command line programs are disabled;
external dependency autodetection is disabled. GPU drivers and OS frameworks remain system
components. Software OpenH264 encoding works without a hardware encoder.

## Verification

`--verify` builds a C++ consumer of the installed CMake package, encodes moving RGBA frames
and stereo audio into MP4, flushes encoders, writes the trailer, reopens and decodes the
movie, and checks frame counts, timestamp spacing, duration, image motion and audio signal.
It also links a shared-library consumer, catching archives that are not actually PIC.
It runs with a restricted PATH and checks the executable's shared dependencies. The movie
and dependency report are under `ffmpeg-build/<platform>-<arch>/<configuration>/verification`.

## Sources and licences

`build-info.json` records source URLs, versions, hashes, platform, architecture and runtime
configuration. `configure-command.txt`, `build-config.h` and `build-components.h` record
FFmpeg configuration. Upstream `ffbuild/config.log` stays in the build tree because it
dumps environment variables; it is excluded from the distributable package.
`share/avffmpeg` contains the exact unmodified source archives, builder scripts and licences.
FFmpeg is built with GPL and nonfree components disabled; OpenH264 replaces GPL libx264.
Static linking still requires observing FFmpeg's LGPL terms when distributing a linked
application, including providing the material needed to relink with a modified library.
OpenH264 source builds do not inherit Cisco's separately distributed binary patent licence.
See [FFmpeg licensing](https://ffmpeg.org/legal.html) and the included upstream licences.
