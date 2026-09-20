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

    @State private var isEditing: Bool = false
    @State private var validationError: SendMessageValidationError?
    @State private var isValidationAlertPresented: Bool = false
    @State private var isSavedURLListPresented = false
    private var viewModel = SendMessageViewModel()

    var body: some View {
        ZStack {
            Color.appBackground
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
                        .onTapGesture {
                            self.isEditing = true
                        }

                        if !inputURL.isEmpty {
                            Button(action: {
                                inputURL = ""
                            }, label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color.appTextSecondary)
                            })
                        }

                        Button(action: {
                            isSavedURLListPresented = true
                        }, label: {
                            Image(systemName: "bookmark.fill")
                                .foregroundStyle(Color.appAccent)
                        })
                    }

                    withIconTextFieldView(
                        icon: Image(systemName: "rectangle.and.pencil.and.ellipsis"),
                        placeholder: "名前を入れてください",
                        text: $inputUsername
                    )
                    .onTapGesture {
                        self.isEditing = true
                    }

                    withIconTextFieldView(
                        icon: Image(systemName: "person.crop.square"),
                        placeholder: "プロフィール画像のURLを入れてください",
                        text: $inputAvatarURL
                    )
                    .onTapGesture {
                        self.isEditing = true
                    }

                    withIconTextFieldView(
                        icon: Image(systemName: "square.and.pencil"),
                        placeholder: "メッセージを入れてください",
                        text: $inputContext
                    )
                    .onTapGesture {
                        self.isEditing = true
                    }
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
                .onTapGesture {
                    self.isEditing = true
                }

                Spacer()
                    .frame(height: 48.0)

                sendButton

                BannerView()
            }
        }
        .alert(isPresented: $isValidationAlertPresented, error: validationError) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            if let recoverySuggestion = error.recoverySuggestion {
                Text(recoverySuggestion)
            }
        }
        .sheet(isPresented: $isSavedURLListPresented) {
            savedURLListSheet
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
                .foregroundStyle(Color.appAccent)
                .frame(width: 24.0, height: 24.0)

            ZStack(alignment: .leading) {
                TextField(
                    "",
                    text: text,
                    prompt: Text(String(localized: placeholder))
                        .foregroundColor(Color.appPlaceholder)
                )
                .textFieldStyle(.capsule)
            }
        }
    }

    /// 保存済み URL から選んで URL 欄に反映するシート
    private var savedURLListSheet: some View {
        NavigationStack {
            SavedWebhookURLListView(
                onSelect: { item in
                    inputURL = item.url
                    isSavedURLListPresented = false
                },
                initialURL: inputURL
            )
            .navigationTitle("保存済みURL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        isSavedURLListPresented = false
                    }
                }
            }
        }
    }

    private var sendButton: some View {
        Button(action: {
            sendMessage()
        }, label: {
            Text("メッセージを送信！")
                .font(.system(size: 24, weight: .semibold, design: .default))
                .foregroundStyle(.white)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 30.0)
                        .foregroundStyle(Color.appAccent)
                        .shadow(radius: 5.0)
                )
        })
    }
}

extension SendMessageView {
    /// 入力内容を検証し、問題があればダイアログを表示、なければ Webhook に送信する
    private func sendMessage() {
        let messageEntity = MessageEntity(
            username: inputUsername,
            avatarURL: inputAvatarURL,
            content: inputContext,
            messageEmbedEntity: MessageEmbedEntity(
                title: inputEmbedTitle
            )
        )

        if let error = viewModel.validate(url: inputURL, messageEntity: messageEntity) {
            validationError = error
            isValidationAlertPresented = true
            return
        }

        viewModel.postDiscordWebhook(url: inputURL, messageEntity: messageEntity)
    }
}

#Preview {
    SendMessageView()
}
