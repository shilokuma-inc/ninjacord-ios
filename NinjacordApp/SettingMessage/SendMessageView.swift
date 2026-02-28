//
//  SendMessageView.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/04/17.
//

import SwiftUI

struct SendMessageView: View {

    @State private var inputURL = ""
    @State private var inputUsername = ""
    @State private var inputAvatarURL = ""
    @State private var inputContext = ""
    @State private var inputEmbedTitle = ""

    private var viewModel = SendMessageViewModel()

    private var isSendEnabled: Bool {
        !inputURL.isEmpty
    }

    var body: some View {
        ZStack {
            backgroundView
            VStack(spacing: .zero) {
                messageFieldsSection
                embedFieldsSection
                Spacer().frame(height: 48.0)
                SendButton(isEnabled: isSendEnabled, action: sendMessage)
                BannerView()
            }
        }
    }
}

// MARK: - Subviews

extension SendMessageView {
    private var backgroundView: some View {
        Color.discordGray
            .ignoresSafeArea(edges: [.top])
            .onTapGesture {
                dismissKeyboard()
            }
    }

    private var messageFieldsSection: some View {
        VStack(spacing: 8.0) {
            Spacer()
            ClearableIconTextField(
                systemIconName: "link.icloud.fill",
                placeholder: "URLを入れてください",
                text: $inputURL
            )
            ClearableIconTextField(
                systemIconName: "rectangle.and.pencil.and.ellipsis",
                placeholder: "名前を入れてください",
                text: $inputUsername
            )
            ClearableIconTextField(
                systemIconName: "person.crop.square",
                placeholder: "プロフィール画像のURLを入れてください",
                text: $inputAvatarURL
            )
            ClearableIconTextField(
                systemIconName: "square.and.pencil",
                placeholder: "メッセージを入れてください",
                text: $inputContext
            )
        }
        .padding(.horizontal)
    }

    private var embedFieldsSection: some View {
        VStack {
            Spacer().frame(height: 24.0)
            ClearableIconTextField(
                systemIconName: "list.clipboard",
                placeholder: "埋め込みタイトルを入れてください",
                text: $inputEmbedTitle
            )
            .padding(.horizontal)
        }
    }
}

// MARK: - Actions

extension SendMessageView {
    private func sendMessage() {
        viewModel.postDiscordWebhook(
            url: inputURL,
            messageEntity: MessageEntity(
                username: inputUsername,
                avatarURL: inputAvatarURL,
                content: inputContext,
                messageEmbedEntity: MessageEmbedEntity(
                    title: inputEmbedTitle
                )
            )
        )
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}

#Preview {
    SendMessageView()
}
