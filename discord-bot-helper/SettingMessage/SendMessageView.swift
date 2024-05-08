//
//  SendMessageView.swift
//  discord-bot-helper
//
//  Created by 村石 拓海 on 2024/04/17.
//

import SwiftUI

struct SendMessageView: View {

    @State var inputURL = ""
    @State var inputUsername = ""
    @State var inputAvatarURL = ""
    @State var inputContext = ""

    @State var inputEmbedTitle = ""
    
    @State var isTapEnable: Bool = false
    private var viewModel = SendMessageViewModel()

    var body: some View {
        ZStack {
            Color.discordGray
                .ignoresSafeArea(edges: [.top])
            VStack(spacing: .zero) {
                VStack(spacing: 8.0) {
                    Spacer()
                    
                    HStack {
                        withIconTextFieldView(
                            icon: Image(systemName: "link.icloud.fill"),
                            placeholder: "URLを入れてください",
                            text: $inputURL
                        )
                        .onChange(of: inputURL, initial: true) { _ in
                            textFieldValidation()
                        }
                        
                        if !inputURL.isEmpty {
                            Button(action: {
                                inputURL = ""
                            }, label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.gray)
                            })
                        }
                    }

                    withIconTextFieldView(
                        icon: Image(systemName: "rectangle.and.pencil.and.ellipsis"),
                        placeholder: "名前を入れてください",
                        text: $inputUsername
                    )

                    withIconTextFieldView(
                        icon: Image(systemName: "person.crop.square"),
                        placeholder: "プロフィール画像のURLを入れてください",
                        text: $inputAvatarURL
                    )

                    withIconTextFieldView(
                        icon: Image(systemName: "square.and.pencil"),
                        placeholder: "メッセージを入れてください",
                        text: $inputContext
                    )
                }
                .padding(.horizontal)

                Spacer()
                    .frame(height: 24.0)

                withIconTextFieldView(
                    icon: Image(systemName: "list.clipboard"),
                    placeholder: "埋め込みタイトルを入れてください",
                    text: $inputEmbedTitle
                )
                .padding(.horizontal)

                Spacer()
                    .frame(height: 48.0)

                sendButton(isTapEnabled: isTapEnable)
                
                BannerView()
            }
        }
    }
}

extension SendMessageView {
    private func withIconTextFieldView(icon: Image, placeholder: String, text: Binding<String>) -> some View {
        HStack {
            icon
                .foregroundStyle(Color.discordPurple)
                .frame(width: 24.0, height: 24.0)

            ZStack(alignment: .leading) {
                TextField(
                    "",
                    text: text,
                    prompt: Text(placeholder)
                        .foregroundColor(Color.discordSuperLightGray)
                )
                .textFieldStyle(.capsule)
            }
        }
    }

    private func sendButton(isTapEnabled: Bool) -> some View {
        Button(action: {
            viewModel.postDiscordWebhook(url: inputURL,
                                         messageEntity: MessageEntity(
                                            username: inputUsername,
                                            avatarURL: inputAvatarURL,
                                            content: inputContext,
                                            messageEmbedEntity: MessageEmbedEntity(
                                                title: inputEmbedTitle
                                            )
                                         )
            )
        }, label: {
            Text("メッセージを送信！")
                .font(.system(size: 24, weight: .semibold, design: .default))
                .foregroundStyle(.white)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 30.0)
                        .foregroundStyle(isTapEnabled ? .indigo : .gray)
                        .foregroundStyle(.ultraThickMaterial)
                        .shadow(radius: 5.0)
                )
        })
        .disabled(!isTapEnabled)
    }
}

extension SendMessageView {
    private func textFieldValidation() {
        if inputURL.isEmpty {
            isTapEnable = false
        } else {
            isTapEnable = true
        }
    }
}

#Preview {
    SendMessageView()
}