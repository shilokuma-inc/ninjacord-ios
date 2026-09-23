//
//  NativeAdView.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/05/09.
//


import SwiftUI
import GoogleMobileAds

struct NativeAdView: UIViewRepresentable {
    let nativeAd: GADNativeAd

    func makeUIView(context: Context) -> GADNativeAdView {
        let nativeAdView = GADNativeAdView()
        
        // Headline
        let headlineLabel = UILabel()
        headlineLabel.font = .boldSystemFont(ofSize: 16)
        headlineLabel.numberOfLines = 0
        headlineLabel.text = nativeAd.headline
        nativeAdView.headlineView = headlineLabel
        
        // Body
        let bodyLabel = UILabel()
        bodyLabel.font = .systemFont(ofSize: 14)
        bodyLabel.numberOfLines = 0
        bodyLabel.text = nativeAd.body
        nativeAdView.bodyView = bodyLabel
        
        // Call To Action
        let ctaButton = UIButton(type: .system)
        ctaButton.setTitle(nativeAd.callToAction, for: .normal)
        ctaButton.isUserInteractionEnabled = false
        nativeAdView.callToActionView = ctaButton
        
        // Stack layout
        let stack = UIStackView(arrangedSubviews: [headlineLabel, bodyLabel, ctaButton])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        nativeAdView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: nativeAdView.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor, constant: -8)
        ])
        
        nativeAdView.nativeAd = nativeAd
        return nativeAdView
    }

    func updateUIView(_ uiView: GADNativeAdView, context: Context) {}
}
