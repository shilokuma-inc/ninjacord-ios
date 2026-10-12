//
//  ImageAttachmentButton.swift
//  NinjacordApp
//

import PhotosUI
import SwiftUI

/// 送信画面の「画像を添付」。写真から 1 枚選び、添付中はサムネイルと外すボタンを出す。
/// PhotosPicker はアプリの外で動くため、写真ライブラリへのアクセス許可は求めない
struct ImageAttachmentButton: View {
    @Binding var attachment: ImageAttachment?
    /// 読み込めなかった・上限に収まらなかったとき
    let onFailure: () -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var isLoading = false

    var body: some View {
        HStack(spacing: 8.0) {
            if let attachment, let thumbnail = UIImage(data: attachment.data) {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36.0, height: 36.0)
                    .clipShape(RoundedRectangle(cornerRadius: 6.0))
                    .accessibilityLabel("添付した画像")

                Button {
                    self.attachment = nil
                    selectedItem = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.appTextSecondary)
                        .frame(width: 44.0, height: 44.0)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("画像を外す")
            } else if isLoading {
                ProgressView()
                    .frame(minWidth: 44.0, minHeight: 44.0)
            } else {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("画像を添付", systemImage: "photo")
                }
                .font(.system(size: 15, weight: .semibold))
                .tint(Color.appAccent)
                .frame(minHeight: 44.0)
            }
        }
        .onChange(of: selectedItem) { item in
            guard let item else { return }
            Task {
                await load(item)
            }
        }
    }

    private func load(_ item: PhotosPickerItem) async {
        isLoading = true
        defer { isLoading = false }
        // 大きな画像の縮小は重いので、メインスレッドを止めないよう別スレッドで行う
        let loaded = try? await item.loadTransferable(type: Data.self)
        let made = await Task.detached { loaded.flatMap { ImageAttachment.make(from: $0) } }.value
        if let made {
            attachment = made
        } else {
            selectedItem = nil
            onFailure()
        }
    }
}
