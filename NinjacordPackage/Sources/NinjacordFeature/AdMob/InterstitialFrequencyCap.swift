//
//  InterstitialFrequencyCap.swift
//  NinjacordApp
//

import Foundation

/// インタースティシャル広告の表示頻度の上限。Discussion #261 の決定により
/// 「1日3回まで（端末のタイムゾーンで日付を区切る）」かつ「前回表示から5分以上」とする
struct InterstitialFrequencyCap {
    static let maxShowsPerDay = 3
    static let minimumInterval: TimeInterval = 5 * 60

    private static let shownDatesKey = "interstitialShownDates"

    private let userDefaults: UserDefaults
    private let calendar: Calendar

    init(userDefaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.userDefaults = userDefaults
        self.calendar = calendar
    }

    /// 今表示してよいか
    func canShow(now: Date = Date()) -> Bool {
        let shownToday = shownDates.filter { calendar.isDate($0, inSameDayAs: now) }
        guard shownToday.count < Self.maxShowsPerDay else { return false }
        if let last = shownDates.max(), now.timeIntervalSince(last) < Self.minimumInterval {
            return false
        }
        return true
    }

    /// 表示したことを記録する
    func recordShown(at date: Date = Date()) {
        // 判定に使うのは今日の分と直近の 1 件だけなので、今日以外の記録は捨てて肥大化を防ぐ
        let kept = shownDates.filter { calendar.isDate($0, inSameDayAs: date) }
        userDefaults.set(kept + [date], forKey: Self.shownDatesKey)
    }

    private var shownDates: [Date] {
        userDefaults.array(forKey: Self.shownDatesKey) as? [Date] ?? []
    }
}
