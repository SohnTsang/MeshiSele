// swift-tools-version: 5.9
// This Package.swift is only for dependency management
// The actual project structure remains in MealDecider.xcodeproj

import PackageDescription

let package = Package(
    name: "MealDeciderDependencies",
    platforms: [
        .iOS(.v15)
    ],
    dependencies: [
        .package(
            url: "https://github.com/firebase/firebase-ios-sdk",
            from: "10.0.0"
        ),
        .package(
            url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git",
            from: "10.0.0"
        )
    ]
) 