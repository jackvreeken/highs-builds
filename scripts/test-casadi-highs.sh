#!/bin/bash
# Overlay a build-casadi-highs.sh result onto a fresh CasADi wheel install and run
# CasADi's conic test suite against it. Run in the same container as the build.
set -euo pipefail

HIGHS_VERSION="${HIGHS_VERSION:-v1.15.1}"
CASADI_VERSION="${CASADI_VERSION:-3.8.1}"
BUILD_DIR="${BUILD_DIR:-build-casadi}"
OUT_DIR="${OUT_DIR:-dist/casadi-${CASADI_VERSION}-highs-${HIGHS_VERSION}}"
PYTHON="${PYTHON:-/opt/python/cp314-cp314/bin/python}"

venv="$(realpath -m "$BUILD_DIR/test-venv")"
rm -rf "$venv"
"$PYTHON" -m venv "$venv"
python="$venv/bin/python"
[[ -d "$venv/Scripts" ]] && python="$venv/Scripts/python.exe"
"$python" -m pip install --quiet "casadi==$CASADI_VERSION" numpy scipy
casadi_dir="$("$python" -c 'import casadi, pathlib; print(pathlib.Path(casadi.__file__).parent.as_posix())')"
rm -f "$casadi_dir"/libhighs.* "$casadi_dir"/libcasadi_conic_highs.*
cp -P "$OUT_DIR"/* "$casadi_dir/"

banner="$("$python" -c '
import casadi as ca
x = ca.SX.sym("x")
ca.qpsol("s", "highs", {"x": x, "f": x**2})(lbx=1)' 2>&1 | grep "Running HiGHS")"
echo "$banner"
if [[ "$HIGHS_VERSION" =~ ^[0-9a-f]{40}$ ]]; then
  [[ "$banner" == *"git hash: ${HIGHS_VERSION:0:7}"* ]]
else
  [[ "$banner" == "Running HiGHS ${HIGHS_VERSION#v} "* ]]
fi

cd "$BUILD_DIR/casadi-src/test/python"
"$python" conic.py
