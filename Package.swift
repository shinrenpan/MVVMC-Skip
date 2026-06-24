// swift-tools-version: 6.1
// This is a Skip (https://skip.dev) package.
import PackageDescription

let package = Package(
  name: "MVVMCSkipDemo",
  defaultLocalization: "en",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [
    .library(name: "MVVMCSkipDemo", type: .dynamic, targets: ["MVVMCSkipDemo"]),
  ],
  dependencies: [
    .package(url: "https://source.skip.tools/skip.git", from: "1.9.3"),
    .package(url: "https://source.skip.tools/skip-ui.git", from: "1.0.0"),
  ],
  targets: [
    .target(
      name: "MVVMCSkipDemo",
      dependencies: [
        .product(name: "SkipUI", package: "skip-ui"),
      ],
      path: "Sources/MVVMCSkipDemo",
      plugins: [.plugin(name: "skipstone", package: "skip")]
    ),
    .testTarget(
      name: "MVVMCSkipDemoTests",
      dependencies: [
        "MVVMCSkipDemo",
        .product(name: "SkipTest", package: "skip"),
      ],
      path: "Tests",
      plugins: [.plugin(name: "skipstone", package: "skip")]
    ),
  ]
)
