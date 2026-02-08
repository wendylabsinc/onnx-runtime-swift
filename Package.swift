// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

let env = ProcessInfo.processInfo.environment

func binaryTarget(
    name: String,
    localPath: String,
    urlEnv: String,
    checksumEnv: String
) -> Target {
    if
        let url = env[urlEnv],
        let checksum = env[checksumEnv],
        !url.isEmpty,
        !checksum.isEmpty
    {
        return .binaryTarget(name: name, url: url, checksum: checksum)
    }

    return .binaryTarget(name: name, path: localPath)
}

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
        binaryTarget(
            name: "ONNXRuntimeCPUBinary",
            localPath: "Artifacts/ONNXRuntimeCPUBinary.artifactbundle",
            urlEnv: "ORT_CPU_URL",
            checksumEnv: "ORT_CPU_CHECKSUM"
        ),
        binaryTarget(
            name: "ONNXRuntimeCUDABinary",
            localPath: "Artifacts/ONNXRuntimeCUDABinary.artifactbundle",
            urlEnv: "ORT_CUDA_URL",
            checksumEnv: "ORT_CUDA_CHECKSUM"
        ),
        binaryTarget(
            name: "ONNXRuntimeROCmBinary",
            localPath: "Artifacts/ONNXRuntimeROCmBinary.artifactbundle",
            urlEnv: "ORT_ROCM_URL",
            checksumEnv: "ORT_ROCM_CHECKSUM"
        ),
        .target(
            name: "ONNXRuntime",
            dependencies: ["ONNXRuntimeCPUBinary"],
            path: "Sources/ONNXRuntime",
            swiftSettings: [
                .define("ORT_CPU")
            ]
        ),
        .target(
            name: "ONNXRuntimeCUDA",
            dependencies: ["ONNXRuntimeCUDABinary"],
            path: "Sources/ONNXRuntime",
            swiftSettings: [
                .define("ORT_CUDA")
            ]
        ),
        .target(
            name: "ONNXRuntimeROCm",
            dependencies: ["ONNXRuntimeROCmBinary"],
            path: "Sources/ONNXRuntime",
            swiftSettings: [
                .define("ORT_ROCM")
            ]
        ),
        .testTarget(
            name: "ONNXRuntimeTests",
            dependencies: ["ONNXRuntime"]
        ),
    ]
)
