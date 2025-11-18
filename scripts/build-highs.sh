#!/bin/bash
set -euo pipefail

# Default values
HIGHS_VERSION="${HIGHS_VERSION:-v1.12.0}"
OPENBLAS_VERSION="${OPENBLAS_VERSION:-v0.3.30}"
BUILD_DIR="${BUILD_DIR:-build}"
install_prefix="install"
linux_rpath="false"
static_only="false"

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --prefix)
      install_prefix="$2"
      shift 2
      ;;
    --rpath)
      linux_rpath="true"
      shift
      ;;
    --static-only)
      static_only="true"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--prefix PATH] [--rpath] [--static-only]"
      exit 1
      ;;
  esac
done

# Detect platform
uname_s=$(uname -s)
if [[ "$uname_s" == "Linux" ]]; then
  PLATFORM="linux"
elif [[ "$uname_s" == "Darwin" ]]; then
  PLATFORM="macos"
elif [[ "$uname_s" =~ ^(MSYS|MINGW|CYGWIN) ]]; then
  PLATFORM="windows"
else
  echo "Unsupported platform: $uname_s"
  exit 1
fi

echo "=== HiGHS Build Script ==="
echo "HiGHS version: $HIGHS_VERSION"
echo "OpenBLAS version: $OPENBLAS_VERSION"
echo "Platform: $PLATFORM"
echo "Build directory: $BUILD_DIR"
echo "Install prefix: $install_prefix"
echo "RPATH: $linux_rpath"
echo "Static-only: $static_only"
echo ""

# Determine OpenBLAS platform name
if [[ -n "${OPENBLAS_PLATFORM:-}" ]]; then
  # Use explicitly set platform name
  openblas_platform="$OPENBLAS_PLATFORM"
else
  # Auto-detect based on runner/container
  if [[ "$PLATFORM" == "linux" ]]; then
    # Check for manylinux/musllinux markers
    if [[ -f /etc/os-release ]]; then
      if grep -q "Alpine" /etc/os-release; then
        # musllinux
        if [[ "$(uname -m)" == "x86_64" ]]; then
          openblas_platform="musllinux_1_2_x86_64"
        elif [[ "$(uname -m)" == "aarch64" ]]; then
          openblas_platform="musllinux_1_2_aarch64"
        fi
      elif [[ -f /etc/redhat-release ]]; then
        # manylinux
        if grep -q "release 7" /etc/redhat-release; then
          # manylinux2014
          if [[ "$(uname -m)" == "x86_64" ]]; then
            openblas_platform="manylinux2014_x86_64"
          elif [[ "$(uname -m)" == "aarch64" ]]; then
            openblas_platform="manylinux2014_aarch64"
          fi
        else
          # manylinux_2_28 or newer
          if [[ "$(uname -m)" == "x86_64" ]]; then
            openblas_platform="manylinux_2_28_x86_64"
          elif [[ "$(uname -m)" == "aarch64" ]]; then
            openblas_platform="manylinux_2_28_aarch64"
          fi
        fi
      fi
    fi

    # Fallback for generic Linux
    if [[ -z "${openblas_platform:-}" ]]; then
      if [[ "$(uname -m)" == "x86_64" ]]; then
        openblas_platform="manylinux_2_28_x86_64"
      elif [[ "$(uname -m)" == "aarch64" ]]; then
        openblas_platform="manylinux_2_28_aarch64"
      fi
    fi
  elif [[ "$PLATFORM" == "macos" ]]; then
    # Detect macOS version
    macos_version=$(sw_vers -productVersion | cut -d. -f1)
    openblas_platform="macos-${macos_version}-arm64"
  elif [[ "$PLATFORM" == "windows" ]]; then
    openblas_platform="windows-x64"
  fi
fi

echo "OpenBLAS platform: $openblas_platform"
echo ""

# Download and extract OpenBLAS
echo "=== Downloading OpenBLAS ==="
openblas_url="https://github.com/jackvreeken/openblas-builds/releases/download/${OPENBLAS_VERSION}/openblas-${OPENBLAS_VERSION}-${openblas_platform}"

if [[ "$PLATFORM" == "windows" ]]; then
  openblas_archive="${openblas_url}.zip"
  echo "Downloading $openblas_archive"
  curl -L -o openblas.zip "$openblas_archive"
  unzip -q openblas.zip
  rm openblas.zip
else
  openblas_archive="${openblas_url}.tar.gz"
  echo "Downloading $openblas_archive"
  curl -L "$openblas_archive" | tar -xz
fi

# Determine library path (lib or lib64)
if [[ -d "lib64" ]]; then
  OPENBLAS_LIB_DIR="$(pwd)/lib64"
elif [[ -d "lib" ]]; then
  OPENBLAS_LIB_DIR="$(pwd)/lib"
else
  echo "Error: OpenBLAS lib directory not found"
  exit 1
fi

OPENBLAS_INCLUDE_DIR="$(pwd)/include"
echo "OpenBLAS library directory: $OPENBLAS_LIB_DIR"
echo "OpenBLAS include directory: $OPENBLAS_INCLUDE_DIR"
echo ""

# Clone or update HiGHS repository
echo "=== Fetching HiGHS Source ==="
if [[ ! -d "HiGHS" ]]; then
  git clone --depth 1 --branch "$HIGHS_VERSION" https://github.com/ERGO-Code/HiGHS.git
else
  echo "HiGHS directory already exists, skipping clone"
fi
echo ""

# Configure CMake
echo "=== Configuring HiGHS ==="
cmake_args=(
  -S HiGHS
  -B "$BUILD_DIR"
  -G Ninja
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_INSTALL_PREFIX="$install_prefix"
  -DFAST_BUILD=ON
  -DBUILD_CXX=ON
  -DBUILD_CXX_EXE=ON
  -DZLIB=ON
  -DBUILD_TESTING=OFF
)

# Set CMAKE_PREFIX_PATH to find OpenBLAS
cmake_args+=(-DCMAKE_PREFIX_PATH="$(pwd)")

# Shared vs static libraries
if [[ "$static_only" == "true" ]]; then
  cmake_args+=(-DBUILD_SHARED_LIBS=OFF)
else
  if [[ "$PLATFORM" == "windows" ]]; then
    # Windows: prefer static by default
    cmake_args+=(-DBUILD_SHARED_LIBS=OFF)
  else
    # Unix: build shared libraries
    cmake_args+=(-DBUILD_SHARED_LIBS=ON)
  fi
fi

# Enable HIPO solver if METIS is available
# Check if METIS is installed
if pkg-config --exists metis 2>/dev/null || [[ -f /usr/include/metis.h ]] || [[ -f /usr/local/include/metis.h ]]; then
  echo "METIS found, enabling HIPO solver"
  cmake_args+=(-DHIPO=ON)
  # Set BLAS vendor to OpenBLAS
  cmake_args+=(-DBLA_VENDOR=OpenBLAS)
  # Set METIS_ROOT for HiGHS to find METIS
  if [[ -f /usr/include/metis.h ]]; then
    cmake_args+=(-DMETIS_ROOT=/usr)
  elif [[ -f /usr/local/include/metis.h ]]; then
    cmake_args+=(-DMETIS_ROOT=/usr/local)
  fi
else
  echo "METIS not found, HIPO solver will be disabled"
  cmake_args+=(-DHIPO=OFF)
fi

# Add RPATH for relocatable binaries on Linux
if [[ "$linux_rpath" == "true" && "$PLATFORM" == "linux" ]]; then
  cmake_args+=(-DCMAKE_BUILD_RPATH_USE_ORIGIN=ON)
  cmake_args+=(-DCMAKE_INSTALL_RPATH='$ORIGIN:$ORIGIN/../lib')
fi

echo "CMake arguments:"
printf '  %s\n' "${cmake_args[@]}"
echo ""

cmake "${cmake_args[@]}"

# Build
echo "=== Building HiGHS ==="
cmake --build "$BUILD_DIR" --parallel

# Install
echo "=== Installing HiGHS ==="
cmake --install "$BUILD_DIR"

echo ""
echo "=== Build Complete ==="
echo "Installation directory: $install_prefix"
echo ""

# Create build-complete marker
touch "$install_prefix/build-complete"

# Display summary
echo "Build summary:"
if [[ -d "$install_prefix/lib" ]]; then
  ls -lh "$install_prefix/lib"/*.a "$install_prefix/lib"/*.so* 2>/dev/null || true
fi
if [[ -d "$install_prefix/bin" ]]; then
  echo ""
  echo "Executable:"
  ls -lh "$install_prefix/bin/highs"* 2>/dev/null || true
fi
