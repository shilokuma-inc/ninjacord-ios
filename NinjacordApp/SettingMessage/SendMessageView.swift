//
//  SendMessageView.swift
//  NinjacordApp
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
    @State private var isEditing: Bool = false
    private var viewModel = SendMessageViewModel()

    var body: some View {
        ZStack {
            Color.discordGray
                .ignoresSafeArea(edges: [.top])
                .onTapGesture {
                    if self.isEditing {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
                        )
                        self.isEditing = false
                    }
                }
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
                        .onTapGesture {
                            self.isEditing = true
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

                    HStack {
                        withIconTextFieldView(
                            icon: Image(systemName: "rectangle.and.pencil.and.ellipsis"),
                            placeholder: "名前を入れてください",
                            text: $inputUsername
                        )
                        .onTapGesture {
                            self.isEditing = true
                        }

                        if !inputUsername.isEmpty {
                            Button(action: {
                                inputUsername = ""
                            }, label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.gray)
                            })
                        }
                    }

                    HStack {
                        withIconTextFieldView(
                            icon: Image(systemName: "person.crop.square"),
                            placeholder: "プロフィール画像のURLを入れてください",
                            text: $inputAvatarURL
                        )
                        .onTapGesture {
                            self.isEditing = true
                        }

                        if !inputAvatarURL.isEmpty {
                            Button(action: {
                                inputAvatarURL = ""
                            }, label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.gray)
                            })
                        }
                    }

                    HStack {
                        withIconTextFieldView(
                            icon: Image(systemName: "square.and.pencil"),
                            placeholder: "メッセージを入れてください",
                            text: $inputContext
                        )
                        .onTapGesture {
                            self.isEditing = true
                        }

                        if !inputContext.isEmpty {
                            Button(action: {
                                inputContext = ""
                            }, label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.gray)
                            })
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()
                    .frame(height: 24.0)

                HStack {
                    withIconTextFieldView(
                        icon: Image(systemName: "list.clipboard"),
                        placeholder: "埋め込みタイトルを入れてください",
                        text: $inputEmbedTitle
                    )
                    .onTapGesture {
                        self.isEditing = true
                    }

                    if !inputEmbedTitle.isEmpty {
                        Button(action: {
                            inputEmbedTitle = ""
                        }, label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.gray)
                        })
                    }
                }
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
    private func withIconTextFieldView(
        icon: Image,
        placeholder: LocalizedStringResource,
        text: Binding<String>
    ) -> some View {
        HStack {
            icon
                .foregroundStyle(Color.discordPurple)
                .frame(width: 24.0, height: 24.0)

            ZStack(alignment: .leading) {
                TextField(
                    "",
                    text: text,
                    prompt: Text(String(localized: placeholder))
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
