// Copyright (c) Renewed Vision, LLC. All rights reserved.

import Foundation
import PackagePlugin

@main
struct LoroBuildPlugin {
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
            self.invokeProRustPreBuild(
                outputDirectory: pluginWorkDirectory
            ),
            self.invokeProRustComplete(
                directory: targetDirectory,
                sourceFiles: sourceFiles,
                outputDirectory: pluginWorkDirectory
            )
        ]
    }

    private func invokeProRustPreBuild(
        outputDirectory: Path
    ) -> Command {
        return .prebuildCommand(
            displayName: "CoreRegistrationClientPreBulid",
            executable: Path("/bin/rm"),
            arguments: [
                "-fr",
                Path("/private/tmp").appending([
                    "CoreRegistrationClientWait.md"
                ])
            ],
            outputFilesDirectory: Path("/dev/null")
        )
    }

    private func invokeProRustComplete(
        directory: Path,
        sourceFiles: FileList,
        outputDirectory: Path
    ) -> Command {
        let derivedData = outputDirectory
            .removingLastComponent() // LoroBuildPlugin
            .removingLastComponent() // RVRegistrationClient
            .removingLastComponent() // rvregistrationclient.output
            .removingLastComponent() // plugins
            .removingLastComponent() // SourcePackages

        let buildProducts = derivedData
            .appending([
                "Build",
                "Products",
                "Debug",
                "CoreRegistrationClient"
            ])
        // the actual products from the ProRust target in ProCore
        let header = buildProducts.appending([
            "CoreRegistrationClient.h"
        ])
        let moduleMap = buildProducts.appending([
            "module.modulemap"
        ])
        // the signal file indicating the ProRust target has completed
        let finished = Path("/private/tmp").appending([
            "CoreRegistrationClientWait.md"
        ])
        // they byproduct quieting the script dependency output check
        let touched = outputDirectory.appending([
            "CoreRegistrationClientWait.md"
        ])

        // a flag to let CoreRegistrationClientWait in RVRegistrationClient know this step has completed
        // note that ProRust always runs at present should that change then a different mechanism will be needed
        return .buildCommand(
            displayName: "CoreRegistrationClientWait",
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

extension LoroBuildPlugin: BuildToolPlugin {
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

extension LoroBuildPlugin: XcodeBuildToolPlugin {
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
