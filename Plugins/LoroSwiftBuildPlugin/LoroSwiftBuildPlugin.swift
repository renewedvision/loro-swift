// Copyright (c) Renewed Vision, LLC. All rights reserved.

import Foundation
import PackagePlugin

@main
struct LoroSwiftBuildPlugin {
    enum PluginError: Error, CustomStringConvertible {
        /// Indicates that the target where the plugin was applied to was not `SourceModuleTarget`.
        case invalidTarget(Target)

        var description: String {
            switch self {
            case let .invalidTarget(target):
                return "Expected a SwiftSourceModuleTarget but got '\(type(of: target))'."
            }
        }
    }

    private func createBuildCommands(
        pluginWorkDirectory: Path,
        sourceFiles: FileList,
        tool: (String) throws -> PackagePlugin.PluginContext.Tool,
        targetDirectory: Path
    ) throws -> [Command] {
        return [
            self.invokePreBuild(
                outputDirectory: pluginWorkDirectory
            ),
            self.invokeComplete(
                directory: targetDirectory,
                sourceFiles: sourceFiles,
                outputDirectory: pluginWorkDirectory
            )
        ]
    }

    private func invokePreBuild(
        outputDirectory: Path
    ) -> Command {
        print("TNS: Returning LoroSwiftBuildPlugin.invokePreBuild() .prebuildCommand")
        return .prebuildCommand(
            displayName: "LoroPreBulid",
            executable: Path("/bin/rm"),
            arguments: [
                "-fr",
                Path("/private/tmp").appending([
                    "LoroSwiftWait.md"
                ])
            ],
            outputFilesDirectory: Path("/dev/null")
        )
    }

    private func invokeComplete(
        directory: Path,
        sourceFiles: FileList,
        outputDirectory: Path
    ) -> Command {
        let derivedData = outputDirectory
            .removingLastComponent() // LoroSwiftBuildPlugin
            .removingLastComponent() // loro-swift
            .removingLastComponent() // loro-swift.output
            .removingLastComponent() // plugins
            .removingLastComponent() // SourcePackages

        let buildProducts = derivedData
            .appending([
                "Build",
                "Products",
                "Debug",
                "loro-swift"
            ])
        // the actual products from the Xcode target's "Run Shell Script" build phase
        let header = buildProducts.appending([
            "loroFFI.h"
        ])
        let moduleMap = buildProducts.appending([
            "loroFFI.modulemap"
        ])
        // the signal file indicating the "Run Shell Script" build phase has completed
        let finished = Path("/private/tmp").appending([
            "LoroSwiftWait.md"
        ])
        // they byproduct quieting the script dependency output check
        let touched = outputDirectory.appending([
            "LoroSwiftWait.md"
        ])

        // Move the sentinel file that the "Run Shell Script" build phase produced to the outputDiretory.
        return .buildCommand(
            displayName: "LoroSwiftWait",
            executable: Path("/bin/mv"),
            arguments: [
                finished,
                touched
            ],
            inputFiles: [header, moduleMap, finished],
            outputFiles: [touched]
        )
    }
}

extension LoroSwiftBuildPlugin: BuildToolPlugin {
    func createBuildCommands(
        context: PluginContext,
        target: Target
    ) async throws -> [Command] {
        guard let swiftTarget = target as? SwiftSourceModuleTarget else {
            throw PluginError.invalidTarget(target)
        }
        return try createBuildCommands(
            pluginWorkDirectory: context.pluginWorkDirectory,
            sourceFiles: swiftTarget.sourceFiles,
            tool: context.tool,
            targetDirectory: target.directory
        )
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension LoroSwiftBuildPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(
        context: XcodePluginContext,
        target: XcodeTarget
    ) throws -> [Command] {
        return try createBuildCommands(
            pluginWorkDirectory: context.pluginWorkDirectory,
            sourceFiles: target.inputFiles,
            tool: context.tool,
            targetDirectory: context.xcodeProject.directory
        )
    }
}
#endif
