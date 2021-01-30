// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FTP",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "FTP",
            targets: ["FTP"]),
    ],
    dependencies: [
         
    ],
    targets: [
        .target(
            name: "FTP",
            dependencies: []),
        .testTarget(
            name: "FTPTests",
            dependencies: ["FTP"]),
    ]
)
