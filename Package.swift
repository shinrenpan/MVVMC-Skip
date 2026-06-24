// swift-tools-version: 5.10
import PackageDescription

let package = Package(
  name: "MVVMCDemo",
  defaultLocalization: "en",
  platforms: [
    .iOS(.v17),
  ],
  products: [
    .library(name: "MVVMCDemo", targets: ["MVVMCDemo"]),
  ],
  targets: [
    .target(
      name: "MVVMCDemo",
      path: "Sources",
      exclude: [
        "App/Info.plist",
      ]
    ),
    .testTarget(
      name: "MVVMCDemoTests",
      dependencies: ["MVVMCDemo"],
      path: "Tests"
    ),
  ]
)
