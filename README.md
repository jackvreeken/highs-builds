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

## CasADi builds

Releases tagged `casadi-3.8.1-highs-<version>` hold `libhighs` and `libcasadi_conic_highs` built
against that HiGHS version, as a drop-in replacement for the pair bundled in the CasADi 3.8.1
`manylinux_2_28_x86_64` (abi3) wheels. The plugin embeds HiGHS C++ classes, so it has to be
rebuilt for every HiGHS version: replacing `libhighs` alone crashes.

The build uses CasADi's own HiGHS build with the wheel's thread flags and applies `patches/`.
`casadi-highs-lower-hessian.patch` passes only the lower triangle of the Hessian: CasADi passes the
full matrix as triangular, which HiGHS >= 1.14 sums into doubled off-diagonals.

To install a release:

```bash
casadi_dir=$(python -c 'import casadi, os; print(os.path.dirname(casadi.__file__))')
rm -f "$casadi_dir"/libhighs.so* "$casadi_dir"/libcasadi_conic_highs.so*
curl -L https://github.com/jackvreeken/highs-builds/releases/download/casadi-3.8.1-highs-v1.15.1/casadi-3.8.1-highs-v1.15.1-manylinux_2_28_x86_64.tar.gz \
  | tar -xz -C "$casadi_dir"
```

To build and test locally:

```bash
docker run --rm -v "$PWD:/work" -w /work -e HIGHS_VERSION=v1.15.1 quay.io/pypa/manylinux_2_28_x86_64 \
  bash -c "scripts/build-casadi-highs.sh && scripts/test-casadi-highs.sh"
```

The `Build HiGHS for CasADi` workflow builds the latest patch release of each HiGHS minor version
from v1.10 that has no release yet, weekly and on every push to master. Dispatch it with
`highs_versions` to build specific versions; delete a release to have it rebuilt.

## License

HiGHS is licensed under the MIT License. See the [HiGHS repository](https://github.com/ERGO-Code/HiGHS) for details.

## Credits

- [HiGHS](https://github.com/ERGO-Code/HiGHS) - High-performance Interior Point Solver
- [OpenBLAS](https://github.com/OpenMathLib/OpenBLAS) - Optimized BLAS library
- [openblas-builds](https://github.com/jackvreeken/openblas-builds) - Pre-built OpenBLAS binaries
