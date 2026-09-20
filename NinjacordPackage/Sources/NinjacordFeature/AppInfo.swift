//
//  AppInfo.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/05/05.
//

import Foundation

final class AppInfo {
    func getVersion() -> String {
        guard let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String else { return "" }
        return "v\(version)"
    }
}
