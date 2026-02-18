import Foundation

do {
    let options = try ArgumentOptions.parse(CommandLine.arguments)
    try Build.performCommand(options)

    // 开始构建 SPIRV-Cross
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

    // 用于生成 Package.swift，这里填入你发布 release 后的地址
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
        // 1. 执行标准的 CMake 编译和安装
        // 这会生成 libspirv-cross-core.a, libspirv-cross-glsl.a 等多个分散的文件
        try super.build(platform: platform, arch: arch)

        let prefix = thinDir(platform: platform, arch: arch)
        let libDir = prefix + "lib"
        
        // 2. [关键修复] 合并静态库
        // BaseBuild 期望找到一个名为 Libspirv_cross.a 的文件，否则它会去尝试找 dylib 并失败
        // 我们需要把所有生成的 spirv-cross 子模块合并成这一个大文件
        let libFiles = try FileManager.default.contentsOfDirectory(atPath: libDir.path)
            .filter { $0.hasPrefix("libspirv-cross") && $0.hasSuffix(".a") }
            .map { (libDir + $0).path }
        
        if !libFiles.isEmpty {
            // 目标文件必须叫 Libspirv_cross.a (对应 Library 枚举 libspirv_cross -> Lib + spirv_cross)
            let mergedLib = libDir + "Libspirv_cross.a"
            
            // 使用 libtool -static -o output input1 input2 ...
            var args = ["-static", "-o", mergedLib.path]
            args.append(contentsOf: libFiles)
            
            try Utility.launch(path: "/usr/bin/libtool", arguments: args)
            print("✅ [Merge] Merged \(libFiles.count) libraries into \(mergedLib.path)")
        } else {
            print("⚠️ [Merge] No static libraries found to merge! Check CMake output.")
        }

        // 3. 生成适配 Meson 的 pkg-config 文件
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
        // MPV 的 meson.build 寻找 'spirv-cross-c-shared'
        let pcPath = pkgConfigDir + "spirv-cross-c-shared.pc"
        
        // 注意：因为我们上面已经合并成了 Libspirv_cross.a，
        // 这里的 Libs 只需要链接这一个由 base.swift 处理后的框架库名称。
        // 但为了稳妥，我们在 Libs 里写 -lLibspirv_cross
        
        let content = """
        prefix=\(prefix.path)
        exec_prefix=${prefix}
        libdir=${prefix}/lib
        includedir=${prefix}/include/spirv_cross

        Name: spirv-cross-c-shared
        Description: SPIR-V Cross (Merged Static Build)
        Version: \(library.version)
        Libs: -L${libdir} -lLibspirv_cross
        Cflags: -I${includedir}
        """

        try content.write(to: pcPath, atomically: true, encoding: .utf8)
        print("✅ [Fix] Generated spirv-cross-c-shared.pc at \(pcPath.path)")
    }
}