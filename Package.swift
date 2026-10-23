// swift-tools-version:5.9
// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín
import PackageDescription

let package = Package(
    name: "faro",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "faro", path: "Sources/faro")
    ]
)
