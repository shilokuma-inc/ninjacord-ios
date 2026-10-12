//
//  LicenseView.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/05/19.
//

import SwiftUI
import LicenseList

struct LicenseView: View {
    /// タップされたライブラリ。nil 以外になると詳細画面へ遷移する
    @State private var selectedLibrary: Library?

    private var isDetailPresented: Binding<Bool> {
        Binding(
            get: { selectedLibrary != nil },
            set: { isPresented in
                if !isPresented {
                    selectedLibrary = nil
                }
            }
        )
    }

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            List {
                Section(content: {
                    ForEach(Library.libraries, id: \.name) { library in
                        Button {
                            selectedLibrary = library
                        } label: {
                            HStack {
                                Text(library.name)
                                    .foregroundStyle(Color.appTextPrimary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(Color.appTextSecondary)
                            }
                        }
                        .listRowBackground(Color.appSurface)
                    }
                }, header: {
                    Text("ライセンス一覧")
                        .foregroundStyle(Color.appTextPrimary)
                })
            }
            .scrollContentBackground(.hidden)
            .background(.clear)
            .navigationDestination(isPresented: isDetailPresented) {
                if let selectedLibrary {
                    LicenseDetailView(library: selectedLibrary)
                }
            }
        }
    }
}

/// ライブラリ 1 件分のライセンス本文を表示する詳細画面
private struct LicenseDetailView: View {
    let library: Library

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let url = library.url {
                        Link(url.absoluteString, destination: url)
                            .font(.footnote)
                            .foregroundStyle(Color.appAccent)
                    }

                    if library.licenseBody.isEmpty {
                        Text("ライセンス本文が見つかりませんでした")
                            .foregroundStyle(Color.appTextSecondary)
                    } else {
                        Text(library.licenseBody)
                            .font(.footnote.monospaced())
                            .foregroundStyle(Color.appTextPrimary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding()
            }
        }
        .navigationTitle(library.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    LicenseView()
}
