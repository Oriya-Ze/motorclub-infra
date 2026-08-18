#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${ROOT}/lambda/resend_email"
BUILD="${SRC}/build"
OUT="${ROOT}/lambda/resend_email.zip"

rm -rf "${BUILD}" "${OUT}"
mkdir -p "${BUILD}"

python3 -m pip install -q -r "${SRC}/requirements.txt" \
  -t "${BUILD}" \
  --platform manylinux2014_x86_64 \
  --implementation cp \
  --python-version 3.12 \
  --only-binary=:all: 2>/dev/null \
  || python3 -m pip install -q -r "${SRC}/requirements.txt" -t "${BUILD}"

cp "${SRC}/handler.py" "${BUILD}/"

(
  cd "${BUILD}"
  zip -qr "${OUT}" .
)

echo "Built ${OUT}"
