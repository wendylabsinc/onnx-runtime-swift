# Artifact Bundle Scaffolding

This directory scaffolds SwiftPM artifact bundles for ONNX Runtime.

Notes:
- The `.a`/`.lib` files are empty placeholders. Replace them with real ONNX Runtime static libraries for each triple.
- The headers under each `include/` directory are placeholders. Replace them with the real ONNX Runtime C headers.
- The `module.modulemap` files define a module that matches each binary target name. Keep them in sync.
- iOS includes simulator variants (`x86_64-apple-ios26.0-simulator`, `arm64-apple-ios26.0-simulator`) in
  addition to device (`arm64-apple-ios26.0`).
- Android triples can vary by toolchain/API level. If your Swift toolchain expects a different triple
  (for example, `aarch64-unknown-linux-android29`), update the `info.json` entry and directory name.
- ONNX Runtime removed the legacy ROCm EP in 1.23; MIGraphX is the supported AMD/ROCm path. The ROCm bundle
  here assumes a MIGraphX-enabled build.
- CUDA/ROCm builds typically require extra system dependencies. You may need to provide additional
  linker flags or client-side system libraries once you integrate real builds.
