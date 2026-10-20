//
//  OnboardingViewTests.swift
//  NinjacordFeatureTests
//

@testable import NinjacordFeature
import Testing

/// オンボーディングのページ構成を確かめる
struct OnboardingViewTests {
    @Test("説明の 4 ページの後ろにテーマのページを足し、5 ページ以内に収める")
    func pageCount() {
        #expect(OnboardingPage.all.count == 4)
        #expect(OnboardingView.pageCount == OnboardingPage.all.count + 1)
        #expect(OnboardingView.pageCount <= 5)
    }
}
