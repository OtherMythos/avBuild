#!/usr/bin/env python3
"""Build the desktop recording libraries without rebuilding other avBuild dependencies."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shlex
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request

SOURCES = {
    'ffmpeg': ('9.0.2', 'https://ffmpeg.org/releases/ffmpeg-9.0.2.tar.xz',
               '8c3850283eb25fa026482078a04051e0be17347b09ef81a0849bec15a96e002e'),
    'openh264': ('2.6.0', 'https://codeload.github.com/cisco/openh264/tar.gz/refs/tags/v2.6.0',
                 '558544ad358283a7ab2930d69a9ceddf913f4a51ee9bf1bfb9e377322af81a69'),
}
SCRIPT_DIR = Path(__file__).resolve().parent


def run(args, **kwargs):
    print('+', subprocess.list2cmdline([str(a) for a in args]), flush=True)
    return subprocess.run([str(a) for a in args], check=True, **kwargs)


def posix(path):
    value = str(path).replace('\\', '/')
    if os.name == 'nt' and len(value) > 1 and value[1] == ':':
        value = '/' + value[0].lower() + value[2:]
    return value


def source(name, cache, directory):
    version, url, digest = SOURCES[name]
    archive = cache / (name + '-' + version + ('.tar.xz' if name == 'ffmpeg' else '.tar.gz'))
    if not archive.exists():
        print('Downloading', url, flush=True)
        with urllib.request.urlopen(url, timeout=120) as response, archive.with_suffix('.download').open('wb') as out:
            shutil.copyfileobj(response, out)
        archive.with_suffix('.download').replace(archive)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != digest:
        raise RuntimeError('SHA256 mismatch: ' + str(archive))
    destination = directory / (name + '-' + version)
    if not destination.exists():
        with tempfile.TemporaryDirectory(prefix='extract-', dir=directory) as extraction:
            with tarfile.open(archive) as contents:
                #Only the exact pinned upstream archives reach extraction, including on Python 3.9.
                if hasattr(tarfile, 'data_filter'):
                    contents.extractall(extraction, filter='data')
                else:
                    contents.extractall(extraction)
            shutil.move(str(Path(extraction) / destination.name), destination)
    return destination


def windows_environment(msys_root):
    if not (msys_root / 'usr/bin/bash.exe').is_file():
        raise RuntimeError('MSYS2 not found. Install it and pass --msys-root (see ffmpeg/README.md).')
    env = os.environ.copy()
    if not shutil.which('cl') or env.get('VSCMD_ARG_TGT_ARCH', '').lower() != 'x64':
        vswhere = Path(os.environ.get('ProgramFiles(x86)', 'C:/Program Files (x86)')) / 'Microsoft Visual Studio/Installer/vswhere.exe'
        location = subprocess.check_output([str(vswhere), '-latest', '-products', '*', '-requires',
                    'Microsoft.VisualStudio.Component.VC.Tools.x86.x64', '-property', 'installationPath'], text=True).strip()
        if not location:
            raise RuntimeError('Visual Studio C++ x64 build tools are required.')
        with tempfile.TemporaryDirectory() as directory:
            script = Path(directory) / 'environment.cmd'
            script.write_text('@echo off\ncall "' + location + '\\Common7\\Tools\\VsDevCmd.bat" -arch=x64 -host_arch=x64 >nul\nif errorlevel 1 exit /b 1\nset\n')
            output = subprocess.check_output(['cmd', '/d', '/c', str(script)], text=True)
        env = dict(line.split('=', 1) for line in output.splitlines() if '=' in line and not line.startswith('='))
    path_key = next(key for key in env if key.upper() == 'PATH')
    compiler_dir = str(Path(shutil.which('cl', path=env[path_key])).parent)
    #Keep all POSIX tools on one MSYS runtime; Git for Windows ships a separate one.
    other_paths = [p for p in env[path_key].split(';')
                   if not p.replace('\\', '/').lower().rstrip('/').endswith(('/usr/bin', '/mingw64/bin'))]
    env[path_key] = ';'.join([compiler_dir, str(msys_root / 'usr/bin'), *other_paths])
    #Convert POSIX source paths for cl.exe, preserving its /std: compiler switch.
    env['MSYS2_ARG_CONV_EXCL'] = '/std:'
    env.pop('MSYS_NO_PATHCONV', None)
    return env


def cmake_package(prefix, flags):
    libraries = []
    required = {'avformat', 'avcodec', 'avutil', 'swscale', 'swresample', 'openh264'}
    found = set()
    tokens = iter(shlex.split(flags))
    for token in tokens:
        if token.startswith('-L') or token.lower().startswith('-libpath:'):
            continue
        if token == '-framework':
            libraries.append('-framework ' + next(tokens))
        elif token.startswith('-l') or token.lower().endswith('.lib'):
            name = token[2:] if token.startswith('-l') else token[:-4]
            candidates = [prefix / 'lib' / filename for filename in (name + '.lib', 'lib' + name + '.a', name + '.a')]
            library = next((p for p in candidates if p.exists()), None)
            if name in required:
                if library is None:
                    raise RuntimeError('Static library missing from package: ' + name)
                found.add(name)
            external = name if token.startswith('-l') else token
            libraries.append('${_avffmpeg_prefix}/lib/' + library.name if library else external)
        else:
            libraries.append(token)
    if found != required:
        raise RuntimeError('Incomplete static link metadata: ' + ', '.join(sorted(required - found)))
    libraries = [value for index, value in enumerate(libraries) if value not in libraries[index + 1:]]
    config = prefix / 'lib/cmake/AVFFmpeg/AVFFmpegConfig.cmake'
    config.parent.mkdir(parents=True, exist_ok=True)
    config.write_text('''#Generated by avBuild's ffmpeg/build.py. Paths remain relative when avBuilt is moved.
get_filename_component(_avffmpeg_prefix "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
include(CMakeFindDependencyMacro)
find_dependency(Threads)
if(NOT TARGET AVFFmpeg::FFmpeg)
    add_library(AVFFmpeg::FFmpeg INTERFACE IMPORTED)
    set_target_properties(AVFFmpeg::FFmpeg PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${_avffmpeg_prefix}/include"
        INTERFACE_LINK_LIBRARIES "''' + ';'.join(libraries) + ''';Threads::Threads")
endif()
unset(_avffmpeg_prefix)
''')


def verify(prefix, work, config, arch, env):
    build = work / 'verification'
    args = ['cmake', '-S', SCRIPT_DIR / 'test', '-B', build,
            '-DAVFFmpeg_DIR=' + str(prefix / 'lib/cmake/AVFFmpeg'), '-DCMAKE_BUILD_TYPE=' + config]
    if sys.platform == 'darwin':
        args += ['-DCMAKE_OSX_ARCHITECTURES=' + arch]
    if os.name == 'nt':
        args += ['-G', 'Ninja']
    run(args, env=env)
    run(['cmake', '--build', build, '--config', config, '--parallel', '2'], env=env)
    executable = build / ('avFFmpegTest.exe' if os.name == 'nt' else 'avFFmpegTest')
    output = build / 'test.mp4'
    clean_env = env.copy()
    for key in list(clean_env):
        if key.upper() in ('PATH', 'LD_LIBRARY_PATH', 'DYLD_LIBRARY_PATH', 'DYLD_FALLBACK_LIBRARY_PATH'):
            del clean_env[key]
    clean_env['PATH'] = str(Path(os.environ.get('SystemRoot', 'C:/Windows')) / 'System32') if os.name == 'nt' else ''
    run([executable, output], env=clean_env)
    if sys.platform == 'darwin':
        dependencies = subprocess.check_output(['otool', '-L', str(executable)], text=True)
    elif sys.platform.startswith('linux'):
        dependencies = subprocess.check_output(['ldd', str(executable)], text=True)
    else:
        tool_path = next(value for key, value in env.items() if key.upper() == 'PATH')
        dumpbin = shutil.which('dumpbin.exe', path=tool_path)
        if not dumpbin:
            raise RuntimeError('Visual Studio dumpbin.exe is required for dependency inspection.')
        dependencies = subprocess.check_output([dumpbin, '/dependents', str(executable)], text=True, env=env)
    if any(name in dependencies.lower() for name in ('avcodec', 'avformat', 'avutil', 'swscale', 'swresample', 'openh264', 'msys-2.0', 'cygwin1')):
        raise RuntimeError('Unexpected FFmpeg/OpenH264 shared dependency:\n' + dependencies)
    (build / 'dependencies.txt').write_text(dependencies)
    print('Static linkage verified. Movie:', output, flush=True)


def install(prefix, cache, root, config, arch, sources):
    #FFmpeg's config.log dumps the environment; keep it in the private build tree.
    if (prefix / 'config.log').exists():
        (prefix / 'config.log').unlink()
    shutil.copy2(sources['ffmpeg'] / 'avbuild/config.h', prefix / 'build-config.h')
    shutil.copy2(sources['ffmpeg'] / 'avbuild/config_components.h', prefix / 'build-components.h')
    flags = (prefix / 'static-link-flags.txt').read_text().strip()
    cmake_package(prefix, flags)
    info = {'sources': {name: {'version': version, 'url': url, 'sha256': digest} for name, (version, url, digest) in SOURCES.items()},
            'platform': sys.platform, 'arch': arch, 'configuration': config,
            'windowsRuntime': ('MDd' if config == 'Debug' else 'MD') if os.name == 'nt' else None}
    (prefix / 'build-info.json').write_text(json.dumps(info, indent=4) + '\n')
    share = prefix / 'share/avffmpeg'
    share.mkdir(parents=True, exist_ok=True)
    for name in SOURCES:
        shutil.copy2(cache / (name + '-' + SOURCES[name][0] + ('.tar.xz' if name == 'ffmpeg' else '.tar.gz')), share)
    for name in ['build.py', 'buildLibraries.sh', 'README.md']:
        shutil.copy2(SCRIPT_DIR / name, share)
    shutil.copytree(SCRIPT_DIR / 'test', share / 'test', dirs_exist_ok=True)
    licenses = share / 'licenses'
    licenses.mkdir(exist_ok=True)
    shutil.copy2(sources['ffmpeg'] / 'COPYING.LGPLv2.1', licenses)
    shutil.copy2(sources['openh264'] / 'LICENSE', licenses / 'OpenH264-LICENSE')
    destination = root / 'avBuilt' / config / 'ffmpeg'
    if destination.exists() and any(destination.iterdir()) and not (destination / 'build-info.json').is_file():
        raise RuntimeError('Refusing to replace an unmanaged directory: ' + str(destination))
    if destination.exists():
        shutil.rmtree(destination)
    shutil.copytree(prefix, destination)
    #Make pkg-config metadata relocatable too; configure used the temporary install prefix.
    for pc in (destination / 'lib/pkgconfig').glob('*.pc'):
        text = pc.read_text()
        for original in (posix(prefix), prefix.as_posix()):
            text = text.replace(original, '${pcfiledir}/../..')
        pc.write_text(text)
    return destination


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('build_root', type=Path)
    parser.add_argument('--config', choices=['Debug', 'Release', 'RelWithDebInfo'], default='Debug')
    parser.add_argument('--arch', choices=['arm64', 'x86_64'])
    parser.add_argument('--jobs', type=int, default=4)
    parser.add_argument('--msys-root', type=Path, default=Path(os.environ.get('AV_MSYS_ROOT', 'C:/msys64')))
    parser.add_argument('--verify', action='store_true')
    parser.add_argument('--verify-only', action='store_true', help='test the installed package without rebuilding dependencies')
    args = parser.parse_args()
    if sys.platform not in ('darwin', 'linux', 'win32'):
        parser.error('Only desktop macOS, Linux and Windows are supported.')
    arch = args.arch or ('arm64' if platform.machine().lower() in ('arm64', 'aarch64') else 'x86_64')
    if args.jobs < 1:
        parser.error('--jobs must be positive')
    if arch == 'arm64' and sys.platform != 'darwin':
        parser.error('arm64 is currently supported on macOS only')
    root = args.build_root.expanduser().resolve()
    if any(c.isspace() for c in str(root)):
        parser.error('FFmpeg/OpenH264 make builds require a build root without whitespace')
    env = windows_environment(args.msys_root.resolve()) if os.name == 'nt' else os.environ.copy()
    bash = args.msys_root.resolve() / 'usr/bin/bash.exe' if os.name == 'nt' else Path('/bin/bash')
    work = root / 'ffmpeg-build' / (sys.platform + '-' + arch) / args.config
    destination = root / 'avBuilt' / args.config / 'ffmpeg'
    if args.verify_only:
        verify(destination, work, args.config, arch, env)
        return
    cache = root / 'ffmpeg-sources'
    cache.mkdir(parents=True, exist_ok=True)
    work.mkdir(parents=True, exist_ok=True)
    ffmpeg = source('ffmpeg', cache, work)
    openh264 = source('openh264', cache, work)
    prefix = work / 'install'
    prefix.mkdir(exist_ok=True)
    recipe = work / 'buildLibraries.sh'
    shutil.copy2(SCRIPT_DIR / 'buildLibraries.sh', recipe)
    command = [posix(recipe), posix(ffmpeg), posix(openh264),
               posix(prefix), args.config, arch, str(args.jobs)]
    run([bash, '--noprofile', '--norc', *command], env=env)
    destination = install(prefix, cache, root, args.config, arch, {'ffmpeg': ffmpeg, 'openh264': openh264})
    if args.verify:
        verify(destination, work, args.config, arch, env)
    print('Installed:', destination, flush=True)


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
