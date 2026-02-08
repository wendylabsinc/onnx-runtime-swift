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

## Usage

```swift
import ONNXRuntime

let env = try ORTEnvironment()
let options = try ORTSessionOptions()
let session = try ORTSession(environment: env, modelPath: "model.onnx", options: options)

let input = try ORTTensor<Float>([0, 1, 2, 3], shape: [2, 2])
let outputs = try session.run(inputs: ["input": input])
let output = outputs["output"]!
let values: [Float] = try output.tensorData()
```

`ORTTensor` also accepts `Span<Element>` and `InlineArray<count, Element>` (Swift 6.2) via convenience initializers.
These initializers copy data into the tensor's internal buffer for safety.

## Artifact Sources

By default, the package uses the local artifact bundles under `Artifacts/`.
For remote development, you can point `Package.swift` at zipped artifact bundles
by setting environment variables before resolving/building:

- `ORT_CPU_URL` / `ORT_CPU_CHECKSUM`
- `ORT_CUDA_URL` / `ORT_CUDA_CHECKSUM`
- `ORT_ROCM_URL` / `ORT_ROCM_CHECKSUM`

`ORT_*_URL` should point to a `.artifactbundle.zip`, and the checksum can be
computed with `swift package compute-checksum <zip>`.

## Examples

```
cd Examples/BasicInference
swift run BasicInference --model /path/to/model.onnx
```

## Notes

- The repository currently contains placeholder artifact files. The CI workflow builds real artifacts and
  stages them into the bundles.
- macOS and iOS artifacts are arm64-only.
- ONNX Runtime is pinned as a git submodule at `v1.21.1` and the CI workflow builds from the submodule.
- For AMD GPUs, ONNX Runtime uses the MIGraphX EP (legacy ROCm EP was removed). The ROCm bundle assumes
  a MIGraphX-enabled build.
