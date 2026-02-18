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
            checksum: "9e150c5fbe19a9cba26848035f960d2251503eaade8191fb26edf9bf568a8ee9"
        ),
        //AUTO_GENERATE_TARGETS_END//
    ]
)
