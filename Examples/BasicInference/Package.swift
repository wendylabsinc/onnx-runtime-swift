// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BasicInference",
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "BasicInference",
            dependencies: [
                .product(name: "ONNXRuntime", package: "ONNXRuntime")
            ]
        )
    ]
)
