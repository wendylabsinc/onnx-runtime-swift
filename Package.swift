// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ONNXRuntime",
    products: [
        .library(
            name: "ONNXRuntime",
            targets: ["ONNXRuntime"]
        ),
        .library(
            name: "ONNXRuntimeCUDA",
            targets: ["ONNXRuntimeCUDA"]
        ),
        .library(
            name: "ONNXRuntimeROCm",
            targets: ["ONNXRuntimeROCm"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "ONNXRuntimeCPUBinary",
            path: "Artifacts/ONNXRuntimeCPUBinary.artifactbundle"
        ),
        .binaryTarget(
            name: "ONNXRuntimeCUDABinary",
            path: "Artifacts/ONNXRuntimeCUDABinary.artifactbundle"
        ),
        .binaryTarget(
            name: "ONNXRuntimeROCmBinary",
            path: "Artifacts/ONNXRuntimeROCmBinary.artifactbundle"
        ),
        .target(
            name: "ONNXRuntime",
            dependencies: ["ONNXRuntimeCPUBinary"]
        ),
        .target(
            name: "ONNXRuntimeCUDA",
            dependencies: ["ONNXRuntimeCUDABinary"]
        ),
        .target(
            name: "ONNXRuntimeROCm",
            dependencies: ["ONNXRuntimeROCmBinary"]
        ),
        .testTarget(
            name: "ONNXRuntimeTests",
            dependencies: ["ONNXRuntime"]
        ),
    ]
)
