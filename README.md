# HiGHS Builds

Automated build system for [HiGHS](https://github.com/ERGO-Code/HiGHS) - High-performance Interior Point Solver for linear optimization.

## Overview

This repository provides pre-compiled HiGHS binaries for multiple platforms, built with:

- **HIPO solver** enabled (requires METIS and BLAS)
- **OpenBLAS** integration from [openblas-builds](https://github.com/jackvreeken/openblas-builds)
- **ZLIB** support
- Both **shared and static** libraries
- **highs CLI executable**

## Supported Platforms

### Linux

- manylinux2014_x86_64
- manylinux_2_28_x86_64
- manylinux_2_28_aarch64

### macOS

- macOS 14 (arm64)
- macOS 15 (arm64)

### Windows

- Windows x64 (MSYS2/UCRT64)

## Build Configuration

### CMake Options

- `FAST_BUILD=ON` - Fast build mode
- `BUILD_CXX=ON` - Build C++ library
- `BUILD_CXX_EXE=ON` - Build highs executable
- `BUILD_SHARED_LIBS=ON/OFF` - Build shared libraries (platform-dependent)
- `ZLIB=ON` - Enable ZLIB support
- `HIPO=ON` - Enable HIPO solver (with METIS and OpenBLAS)

### Dependencies

- **OpenBLAS**: Downloaded from [jackvreeken/openblas-builds](https://github.com/jackvreeken/openblas-builds)
- **METIS**: Installed from system packages
- **ZLIB**: System-provided

## Local Build

### Prerequisites

- CMake >= 3.15
- Ninja
- C++ compiler (g++/clang++/MSVC)
- gfortran (for OpenBLAS Fortran interface)
- METIS library

### Build Script

```bash
./scripts/build-highs.sh --prefix install
```

Options:

- `--prefix PATH` - Installation prefix (default: `install`)
- `--rpath` - Add `$ORIGIN` RPATH for relocatable binaries (Linux only)
- `--static-only` - Build static libraries only

### Environment Variables

- `HIGHS_VERSION` - HiGHS version tag (e.g., `v1.12.0`)
- `OPENBLAS_VERSION` - OpenBLAS version tag (e.g., `v0.3.30`)
- `BUILD_DIR` - Build directory (default: `build`)

## Installation

### Download Pre-built Binaries

Download the latest release for your platform:

```bash
HIGHS_VERSION=v1.12.0
PLATFORM=manylinux_2_28_x86_64

# Linux/macOS
curl -L https://github.com/YOUR_USERNAME/highs-builds/releases/download/${HIGHS_VERSION}/highs-${HIGHS_VERSION}-${PLATFORM}.tar.gz | tar -xz

# Windows
curl -L -o highs.zip https://github.com/YOUR_USERNAME/highs-builds/releases/download/${HIGHS_VERSION}/highs-${HIGHS_VERSION}-${PLATFORM}.zip
unzip highs.zip
```

### Directory Structure

```
install/
├── include/highs/          # Header files
│   ├── Highs.h
│   ├── HConfig.h
│   └── ...
├── lib/                    # Libraries
│   ├── libhighs.a         # Static library
│   ├── libhighs.so*       # Shared library (Linux)
│   ├── cmake/highs/       # CMake package config
│   └── pkgconfig/         # pkg-config file
└── bin/
    └── highs              # CLI executable
```

### Using in CMake

```cmake
find_package(highs REQUIRED)
target_link_libraries(your_target highs::highs)
```

### Using with pkg-config

```bash
gcc -o myapp myapp.c $(pkg-config --cflags --libs highs)
```

## CI/CD

Builds are automated via GitHub Actions:

- **Weekly schedule**: Fridays at 02:00 UTC
- **Manual dispatch**: Trigger builds with optional version override
- **Automatic releases**: Creates GitHub releases with platform-specific archives

## License

HiGHS is licensed under the MIT License. See the [HiGHS repository](https://github.com/ERGO-Code/HiGHS) for details.

## Credits

- [HiGHS](https://github.com/ERGO-Code/HiGHS) - High-performance Interior Point Solver
- [OpenBLAS](https://github.com/OpenMathLib/OpenBLAS) - Optimized BLAS library
- [openblas-builds](https://github.com/jackvreeken/openblas-builds) - Pre-built OpenBLAS binaries
