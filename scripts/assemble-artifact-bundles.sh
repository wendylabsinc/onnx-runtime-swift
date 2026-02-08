#!/usr/bin/env bash
set -euo pipefail

# Assembles artifact bundles by copying built ONNX Runtime libs/headers
# into the scaffolded bundle directories.
#
# Expected input layout:
#   build/ort/<variant>/<triple>/libonnxruntime.a (or onnxruntime.lib on Windows)
#   build/ort/<variant>/<triple>/include/...
#
# Variants:
#   cpu | cuda | rocm

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build/ort"

copy_variant() {
  local variant="$1"
  local bundle_name="$2"
  local triples=(${3})

  local bundle_dir="${ROOT_DIR}/Artifacts/${bundle_name}.artifactbundle"
  if [[ ! -d "${bundle_dir}" ]]; then
    echo "Missing bundle directory: ${bundle_dir}" >&2
    exit 1
  fi

  for triple in "${triples[@]}"; do
    local src_dir="${BUILD_DIR}/${variant}/${triple}"
    local dst_dir="${bundle_dir}/${triple}"

    if [[ ! -d "${src_dir}" ]]; then
      echo "Missing build output: ${src_dir}" >&2
      exit 1
    fi

    mkdir -p "${dst_dir}"

    local lib_src="${src_dir}/libonnxruntime.a"
    local lib_dst="${dst_dir}/libonnxruntime.a"

    if [[ "${triple}" == *windows* ]]; then
      lib_src="${src_dir}/onnxruntime.lib"
      lib_dst="${dst_dir}/onnxruntime.lib"
    fi

    if [[ ! -f "${lib_src}" ]]; then
      echo "Missing library: ${lib_src}" >&2
      exit 1
    fi

    if [[ ! -d "${src_dir}/include" ]]; then
      echo "Missing headers: ${src_dir}/include" >&2
      exit 1
    fi

    rm -rf "${dst_dir}/include"
    mkdir -p "${dst_dir}/include"
    cp -R "${src_dir}/include/" "${dst_dir}/"

    cp "${lib_src}" "${lib_dst}"
  done
}

copy_variant "cpu" "ONNXRuntimeCPUBinary" \
  "arm64-apple-macosx26.0 x86_64-apple-macosx26.0 arm64-apple-ios26.0 x86_64-apple-ios26.0-simulator arm64-apple-ios26.0-simulator x86_64-unknown-linux-gnu aarch64-unknown-linux-gnu x86_64-unknown-windows-msvc aarch64-unknown-windows-msvc aarch64-unknown-linux-android28"

copy_variant "cuda" "ONNXRuntimeCUDABinary" \
  "x86_64-unknown-linux-gnu aarch64-unknown-linux-gnu"

copy_variant "rocm" "ONNXRuntimeROCmBinary" \
  "x86_64-unknown-linux-gnu aarch64-unknown-linux-gnu"

echo "Artifact bundles updated under ${ROOT_DIR}/Artifacts"
