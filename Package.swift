// swift-tools-version: 6.1
// This is a Skip (https://skip.dev) package.
import PackageDescription

let package = Package(
  name: "MVVMCDemo",
  defaultLocalization: "en",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "MVVMCDemo", type: .dynamic, targets: ["MVVMCDemo"]),
  ],
  dependencies: [
    .package(url: "https://source.skip.tools/skip.git", from: "1.9.3"),
    .package(url: "https://source.skip.tools/skip-ui.git", from: "1.0.0"),
  ],
  targets: [
    // NOTE: The `skipstone` plugin is intentionally not yet bound to these targets.
    // It will be wired in a later step alongside the per-feature `#if !SKIP`
    // wrapping + ViewModel rewrites, so iOS xcodebuild stays green throughout.
    // See Migration Log M5 for the reasoning.
    .target(
      name: "MVVMCDemo",
      dependencies: [
        .product(name: "SkipUI", package: "skip-ui"),
      ],
      path: "Sources",
      exclude: [
        "App/Info.plist",
      ]
    ),
    .testTarget(
      name: "MVVMCDemoTests",
      dependencies: [
        "MVVMCDemo",
        .product(name: "SkipTest", package: "skip"),
      ],
      path: "Tests"
    ),
  ]
)
