// swift-tools-version: 5.9

import PackageDescription

// アプリ本体（View / ViewModel / 外部 SDK 依存）を保持するローカル Swift Package。
// ファイルの追加・削除はこのパッケージ配下で完結し、NinjacordApp.xcodeproj に差分が出ない。
let package = Package(
    name: "NinjacordPackage",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "NinjacordFeature",
            targets: ["NinjacordFeature"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire", from: "5.9.1"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.24.0"),
        .package(url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git", from: "11.3.0"),
        .package(url: "https://github.com/cybozu/LicenseList", from: "2.2.0")
    ],
    targets: [
        .target(
            name: "NinjacordFeature",
            dependencies: [
                .product(name: "Alamofire", package: "Alamofire"),
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "GoogleMobileAds", package: "swift-package-manager-google-mobile-ads"),
                .product(name: "LicenseList", package: "LicenseList")
            ]
        )
    ]
)
