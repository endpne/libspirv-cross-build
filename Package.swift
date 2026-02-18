// swift-tools-version:5.8

import PackageDescription

let package = Package(
    name: "libass",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13)],
    products: [
        .library(
            name: "libass",
            targets: ["_Libass"]
        ),
    ],
    targets: [
        // Need a dummy target to embedded correctly.
        // https://github.com/apple/swift-package-manager/issues/6069
        .target(
            name: "_Libass",
            dependencies: ["Libunibreak", "Libfreetype", "Libfribidi", "Libharfbuzz", "Libass"],
            path: "Sources/_Dummy"
        ),
        //AUTO_GENERATE_TARGETS_BEGIN//

        .binaryTarget(
            name: "Libspirv_cross",
            url: "https://github.com/endpne/libspirv-cross-build/releases/download/1.4.309/Libspirv_cross.xcframework.zip",
            checksum: "0b090d3de5ec80b2c0f6844c17b58ba2a10973b7cce9783dc916c9b72e90967d"
        ),
        //AUTO_GENERATE_TARGETS_END//
    ]
)
