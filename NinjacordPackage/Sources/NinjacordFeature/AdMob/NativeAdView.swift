//
//  NativeAdView.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/05/09.
//

import SwiftUI
import GoogleMobileAds

/// ネイティブ広告の表示 View。
/// 高さは内容から決まるため、呼び出し側でアスペクト比を固定しないこと。
struct NativeAdView: UIViewRepresentable {
    let nativeAd: GADNativeAd

    func makeUIView(context: Context) -> GADNativeAdView {
        let nativeAdView = GADNativeAdView()

        let headlineLabel = makeHeadlineLabel()
        let iconImageView = makeIconImageView()
        let mediaView = makeMediaView()
        let bodyLabel = makeBodyLabel()
        let ctaButton = makeCallToActionButton()

        nativeAdView.headlineView = headlineLabel
        nativeAdView.iconView = iconImageView
        nativeAdView.mediaView = mediaView
        nativeAdView.bodyView = bodyLabel
        nativeAdView.callToActionView = ctaButton

        let headerStack = UIStackView(arrangedSubviews: [makeAdBadge(), iconImageView, headlineLabel])
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 8

        let stack = UIStackView(arrangedSubviews: [headerStack, mediaView, bodyLabel, ctaButton])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        nativeAdView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: nativeAdView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: nativeAdView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: nativeAdView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: nativeAdView.bottomAnchor)
        ])

        nativeAdView.nativeAd = nativeAd
        return nativeAdView
    }

    func updateUIView(_ uiView: GADNativeAdView, context: Context) {}

    /// List の行の高さを内容から決めるため、幅に対して必要な高さを返す。
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: GADNativeAdView, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0, width < .greatestFiniteMagnitude else { return nil }

        let height = uiView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height

        return CGSize(width: width, height: height)
    }
}

// MARK: - 各パーツの生成

private extension NativeAdView {
    /// 広告であることを示すバッジ（AdMob のポリシー上必須）。
    func makeAdBadge() -> UIView {
        let label = UILabel()
        label.text = String(localized: "広告")
        label.font = .boldSystemFont(ofSize: 11)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false

        let container = UIView()
        container.backgroundColor = .appAccent
        container.layer.cornerRadius = 4
        container.setContentHuggingPriority(.required, for: .horizontal)
        container.setContentCompressionResistancePriority(.required, for: .horizontal)
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6)
        ])

        return container
    }

    func makeHeadlineLabel() -> UILabel {
        let label = UILabel()
        label.font = .boldSystemFont(ofSize: 16)
        label.numberOfLines = 2
        label.text = nativeAd.headline
        label.textColor = .appTextPrimary
        return label
    }

    func makeIconImageView() -> UIImageView {
        let imageView = UIImageView(image: nativeAd.icon?.image)
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 6
        imageView.clipsToBounds = true
        imageView.isHidden = nativeAd.icon?.image == nil
        imageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 28),
            imageView.heightAnchor.constraint(equalToConstant: 28)
        ])

        return imageView
    }

    func makeMediaView() -> GADMediaView {
        let mediaView = GADMediaView()
        let mediaContent = nativeAd.mediaContent
        mediaView.mediaContent = mediaContent
        mediaView.contentMode = .scaleAspectFill
        mediaView.clipsToBounds = true
        mediaView.isHidden = !mediaContent.hasVideoContent && mediaContent.mainImage == nil
        mediaView.translatesAutoresizingMaskIntoConstraints = false

        // 縦長の素材でセルが極端に高くならないよう、下限のアスペクト比を設ける
        let aspectRatio = mediaContent.aspectRatio > 0 ? max(mediaContent.aspectRatio, 1.2) : 16.0 / 9.0
        mediaView.heightAnchor.constraint(
            equalTo: mediaView.widthAnchor,
            multiplier: 1 / aspectRatio
        ).isActive = true

        return mediaView
    }

    func makeBodyLabel() -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.numberOfLines = 3
        label.text = nativeAd.body
        label.textColor = .appTextSecondary
        label.isHidden = nativeAd.body == nil
        return label
    }

    func makeCallToActionButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(nativeAd.callToAction, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 15)
        button.backgroundColor = .appAccent
        button.layer.cornerRadius = 8
        button.isHidden = nativeAd.callToAction == nil
        // タップは GADNativeAdView 側で処理させる
        button.isUserInteractionEnabled = false
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 40).isActive = true
        return button
    }
}

// MARK: - テーマ色

private extension UIColor {
    /// Color のアセットは `Extension+Color` と同じものを参照する
    static let appAccent = UIColor(named: "AppAccent") ?? .systemBlue
    static let appTextPrimary = UIColor(named: "AppTextPrimary") ?? .label
    static let appTextSecondary = UIColor(named: "AppTextSecondary") ?? .secondaryLabel
}
