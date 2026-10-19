#!/bin/bash
set -euo pipefail

FFMPEG_SOURCE=$1
OPENH264_SOURCE=$2
INSTALL_DIR=$3
BUILD_TYPE=$4
TARGET_ARCH=$5
NUM_THREADS=$6

case "$(uname -s)" in
    MSYS*|MINGW*) INSTALL_DIR=$(cygpath -m "$INSTALL_DIR") ;;
esac

for tool in make pkg-config; do
    command -v "$tool" >/dev/null || { echo "Required build tool missing: $tool" >&2; exit 1; }
done
if [ "$TARGET_ARCH" = x86_64 ]; then
    command -v nasm >/dev/null || { echo 'NASM is required for x86_64 builds.' >&2; exit 1; }
fi

OPENH264_TYPE=Release
if [ "$BUILD_TYPE" = Debug ]; then OPENH264_TYPE=Debug; fi
OPENH264_FLAGS=("PREFIX=$INSTALL_DIR" "ARCH=$TARGET_ARCH" "BUILDTYPE=$OPENH264_TYPE")
FFMPEG_DEBUG_FLAG=--enable-debug=1
if [ "$BUILD_TYPE" = Debug ]; then FFMPEG_DEBUG_FLAG=--enable-debug=3; fi
FFMPEG_FLAGS=(
    "--prefix=$INSTALL_DIR" "--arch=$TARGET_ARCH"
    --enable-static --disable-shared --enable-pic
    --disable-autodetect --disable-everything --disable-programs --disable-doc
    --disable-network --disable-avdevice --disable-avfilter
    --disable-gpl --disable-nonfree
    --enable-avcodec --enable-avformat --enable-avutil --enable-swscale --enable-swresample
    --enable-libopenh264 --enable-encoder=libopenh264,aac
    --enable-decoder=h264,aac --enable-parser=h264,aac
    --enable-muxer=mp4 --enable-demuxer=mov --enable-protocol=file
    --pkg-config=pkg-config --pkg-config-flags=--static
)
case "$(uname -s)" in
    Darwin)
        OPENH264_FLAGS+=(OS=darwin STATIC_LDFLAGS=-lc++)
        FFMPEG_FLAGS+=(--enable-videotoolbox --enable-encoder=h264_videotoolbox
            "--extra-cflags=-arch $TARGET_ARCH" "--extra-ldflags=-arch $TARGET_ARCH")
        ;;
    Linux)
        OPENH264_FLAGS+=(OS=linux)
        #The H.264 decoder's x86 assembly emits non-PIC references even with
        #--enable-pic, so a static archive cannot link into avCore.so.
        FFMPEG_FLAGS+=(--enable-pthreads --disable-inline-asm --disable-x86asm)
        ;;
    MSYS*|MINGW*)
        OPENH264_FLAGS+=(OS=msvc)
        FFMPEG_DEBUG_FLAG=--enable-debug
        if [ "$BUILD_TYPE" = Debug ]; then
            OPENH264_FLAGS+=("CFLAGS_DEBUG=-Od -Oy- -Zi -FS -RTC1 -D_DEBUG -MDd")
            FFMPEG_FLAGS+=(--extra-cflags=-MDd)
        else
            OPENH264_FLAGS+=("CFLAGS_OPT=-O2 -Ob1 -Zi -FS -DNDEBUG -MD")
            FFMPEG_FLAGS+=(--extra-cflags=-MD)
        fi
        FFMPEG_FLAGS+=(--toolchain=msvc --target-os=win64 --enable-w32threads)
        ;;
    *) echo 'Unsupported desktop platform' >&2; exit 1 ;;
esac
FFMPEG_FLAGS+=("$FFMPEG_DEBUG_FLAG")
if [ "$BUILD_TYPE" = Debug ]; then
    case "$(uname -s)" in
        #MSVC /Od retains references behind constant false feature checks in FFmpeg.
        MSYS*|MINGW*) FFMPEG_FLAGS+=(--optflags=-O1) ;;
        *) FFMPEG_FLAGS+=(--disable-optimizations) ;;
    esac
fi

#Do not let unrelated installed packages alter configure results.
export PKG_CONFIG_PATH=
export PKG_CONFIG_LIBDIR="$INSTALL_DIR/lib/pkgconfig"
case "$(uname -s)" in
    MSYS*|MINGW*) export PKG_CONFIG_LIBDIR="$(cygpath -u "$INSTALL_DIR")/lib/pkgconfig" ;;
esac
cd "$OPENH264_SOURCE"
make -j"$NUM_THREADS" "${OPENH264_FLAGS[@]}" install-static
mkdir -p "$FFMPEG_SOURCE/avbuild"
cd "$FFMPEG_SOURCE/avbuild"
printf '%q ' "$FFMPEG_SOURCE/configure" "${FFMPEG_FLAGS[@]}" > "$INSTALL_DIR/configure-command.txt"
printf '\n' >> "$INSTALL_DIR/configure-command.txt"
../configure "${FFMPEG_FLAGS[@]}"
make -j"$NUM_THREADS"
make install
pkg-config --static --libs libavformat libavcodec libswscale libswresample libavutil > "$INSTALL_DIR/static-link-flags.txt"
