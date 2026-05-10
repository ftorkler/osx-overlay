// swift-tools-version:5.9
// This Package.swift exists to provide SourceKit-LSP with module
// information for editor support (code completion, type resolution
// across files, etc.). The actual build is driven by CMakeLists.txt.

import PackageDescription

let package = Package(
    name: "osx-overlay",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "osx-overlay",
            path: "src"
        )
    ]
)
