# ONNXRuntime (Swift)

Swift 6.2 package wrapping ONNX Runtime with cross-platform binary artifacts.

## Status

[![CI: Artifact Bundles](https://github.com/wendylabsinc/onnx-runtime-swift/actions/workflows/onnxruntime-artifacts.yml/badge.svg)](https://github.com/wendylabsinc/onnx-runtime-swift/actions/workflows/onnxruntime-artifacts.yml)
[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange)](https://www.swift.org/download/)
[![macOS 26](https://img.shields.io/badge/macOS-26-blue)](https://developer.apple.com/macos/)
[![iOS 26](https://img.shields.io/badge/iOS-26-blue)](https://developer.apple.com/ios/)
[![Linux x86_64](https://img.shields.io/badge/Linux-x86__64-blue)](https://www.kernel.org/)
[![Linux arm64](https://img.shields.io/badge/Linux-arm64-blue)](https://www.kernel.org/)
[![Windows x86_64](https://img.shields.io/badge/Windows-x86__64-blue)](https://learn.microsoft.com/windows/)
[![Windows arm64](https://img.shields.io/badge/Windows-arm64-blue)](https://learn.microsoft.com/windows/)
[![Android arm64](https://img.shields.io/badge/Android-arm64-blue)](https://developer.android.com/)
[![CUDA](https://img.shields.io/badge/Linux-CUDA-76B900?logo=nvidia&logoColor=white)](https://developer.nvidia.com/cuda-zone)
[![ROCm](https://img.shields.io/badge/Linux-ROCm-ED1C24?logo=amd&logoColor=white)](https://www.amd.com/en/products/software/rocm.html)

## Package Layout

- CPU: `ONNXRuntime`
- CUDA (Linux): `ONNXRuntimeCUDA`
- ROCm/MIGraphX (Linux): `ONNXRuntimeROCm`

Artifacts live under `Artifacts/` as SwiftPM static library bundles.

## CI Builds

A GitHub Actions workflow builds ONNX Runtime for each target and assembles artifact bundles:
- Workflow: `.github/workflows/onnxruntime-artifacts.yml`
- Trigger manually with `workflow_dispatch`

## Notes

- The repository currently contains placeholder artifact files. The CI workflow builds real artifacts and
  stages them into the bundles.
- For AMD GPUs, ONNX Runtime uses the MIGraphX EP (legacy ROCm EP was removed). The ROCm bundle assumes
  a MIGraphX-enabled build.
