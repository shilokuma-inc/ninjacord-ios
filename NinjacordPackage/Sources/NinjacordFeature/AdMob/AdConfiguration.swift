//
//  AdConfiguration.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2026/09/21.
//

import Foundation

enum AdConfiguration {
    /// 広告を表示するかどうか。
    /// App Store 用スクリーンショットに広告を写り込ませないため、
    /// Build Configuration の `ADS_ENABLED` を Info.plist 経由で参照して切り替える。
    static var isEnabled: Bool {
        // キーが無いビルドでは従来どおり広告を表示する
        guard let value = Bundle.main.object(forInfoDictionaryKey: "AdsEnabled") as? String else { return true }
        return (value as NSString).boolValue
    }
}
