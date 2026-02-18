import Foundation

do {
    let options = try ArgumentOptions.parse(CommandLine.arguments)
    try Build.performCommand(options)

    // 只执行 SpirvCross 的构建
    try BuildSpirvCross().buildALL()
} catch {
    print("ERROR: \(error.localizedDescription)")
    exit(1)
}

enum Library: String, CaseIterable {
    case libspirv_cross
    
    var version: String {
        switch self {
        case .libspirv_cross:
            return "vulkan-sdk-1.4.309.0" 
        }
    }

    var url: String {
        switch self {
        case .libspirv_cross:
            return "https://github.com/KhronosGroup/SPIRV-Cross"
        }
    }

    // 生成 Package.swift 用，即使不发布 Package 也可以留着
    var targets : [PackageTarget] {
        switch self {
        case .libspirv_cross:
            return [
                .target(
                    name: "Libspirv_cross",
                    url: "https://github.com/endpne/libspirv-cross-build/releases/download/\(BaseBuild.options.releaseVersion)/Libspirv_cross.xcframework.zip",
                    checksum: "https://github.com/endpne/libspirv-cross-build/releases/download/\(BaseBuild.options.releaseVersion)/Libspirv_cross.xcframework.checksum.txt"
                ),
            ]
        }
    }
}

private class BuildSpirvCross: BaseBuild {
    init() {
        super.init(library: .libspirv_cross)
    }

    override func arguments(platform: PlatformType, arch: ArchType) -> [String] {
        return [
            "-DSPIRV_CROSS_CLI=OFF",
            "-DSPIRV_CROSS_ENABLE_TESTS=OFF",
            "-DSPIRV_CROSS_ENABLE_C_API=ON",
            "-DSPIRV_CROSS_SHARED=OFF",
            "-DSPIRV_CROSS_STATIC=ON",
        ]
    }

    override func build(platform: PlatformType, arch: ArchType) throws {
        // 1. 标准编译
        try super.build(platform: platform, arch: arch)

        // 2. 生成适配 Meson 的 pkg-config 文件
        try generatePkgConfig(platform: platform, arch: arch)
    }

    private func generatePkgConfig(platform: PlatformType, arch: ArchType) throws {
        let prefix = thinDir(platform: platform, arch: arch)
        let pkgConfigDir = prefix + ["lib", "pkgconfig"]
        
        // 确保目录存在
        if !FileManager.default.fileExists(atPath: pkgConfigDir.path) {
            try FileManager.default.createDirectory(at: pkgConfigDir, withIntermediateDirectories: true, attributes: nil)
        }

        // 生成 spirv-cross-c-shared.pc
        // 这是为了欺骗 Meson，让它以为找到了 Shared 库，实际上链接的是静态库
        let pcPath = pkgConfigDir + "spirv-cross-c-shared.pc"
        
        // 显式列出所有需要的静态库
        let libs = "-lspirv-cross-c -lspirv-cross-core -lspirv-cross-glsl -lspirv-cross-cpp -lspirv-cross-reflect -lspirv-cross-msl -lspirv-cross-hlsl"

        let content = """
        prefix=\(prefix.path)
        exec_prefix=${prefix}
        libdir=${prefix}/lib
        includedir=${prefix}/include/spirv_cross

        Name: spirv-cross-c-shared
        Description: SPIR-V Cross (Static Build with Shared Shim)
        Version: \(library.version)
        Libs: -L${libdir} \(libs)
        Cflags: -I${includedir}
        """

        try content.write(to: pcPath, atomically: true, encoding: .utf8)
        print("✅ [Fix] Generated spirv-cross-c-shared.pc at \(pcPath.path)")
    }
}