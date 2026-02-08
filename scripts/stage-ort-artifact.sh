#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "usage: $0 <ort_root> <build_dir> <dest_dir> [libname]" >&2
  exit 1
fi

ORT_ROOT="$1"
BUILD_DIR="$2"
DEST_DIR="$3"
LIB_NAME="${4:-libonnxruntime.a}"

if [[ ! -d "${ORT_ROOT}" ]]; then
  echo "ORT root not found: ${ORT_ROOT}" >&2
  exit 1
fi

if [[ ! -d "${BUILD_DIR}" ]]; then
  echo "Build dir not found: ${BUILD_DIR}" >&2
  exit 1
fi

LIB_PATH=$(find "${BUILD_DIR}" -type f -name "${LIB_NAME}" | head -n 1 || true)
if [[ -z "${LIB_PATH}" ]]; then
  echo "Library ${LIB_NAME} not found under ${BUILD_DIR}" >&2
  exit 1
fi

mkdir -p "${DEST_DIR}"
cp "${LIB_PATH}" "${DEST_DIR}/"

rm -rf "${DEST_DIR}/include"
mkdir -p "${DEST_DIR}/include"
cp -R "${ORT_ROOT}/include/onnxruntime" "${DEST_DIR}/include/"
