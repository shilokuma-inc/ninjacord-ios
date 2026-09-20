//
//  LicenseView.swift
//  NinjacordApp
//
//  Created by 村石 拓海 on 2024/05/19.
//

import SwiftUI
import LicenseList

struct LicenseView: View {
    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea(edges: [.top])
            List {
                Section(content: {
                    ForEach(Library.libraries, id: \.name) { library in
                        Text(library.name)
                            .listRowBackground(Color.appSurface)
                            .foregroundStyle(Color.appTextPrimary)
                    }
                }, header: {
                    Text("ライセンス一覧")
                        .foregroundStyle(Color.appTextSecondary)
                })
            }
            .scrollContentBackground(.hidden)
            .background(.clear)
        }
    }
}

#Preview {
    LicenseView()
}
