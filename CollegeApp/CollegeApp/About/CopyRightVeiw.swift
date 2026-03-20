//
//  CopyRightView.swift
//  CollegeApp
//
//  Created by 王耀偉 on 2026/3/20.
//

import SwiftUI

struct CopyRightView: View {

    private let disclaimers: [(icon: String, color: Color, text: String)] = [
        (
            icon: "person.fill",
            color: .teal,
            text: "NKUST Plus 為 Wesley Wang 個人開發之非官方應用程式。"
        ),
        (
            icon: "building.columns.fill",
            color: .blue,
            text: "本 App 與國立高雄科技大學無任何合作或隸屬關係。"
        ),
        (
            icon: "doc.text.fill",
            color: .orange,
            text: "本 App 所提供之相關資訊僅供參考，實際內容仍以國立高雄科技大學官方公告為準。"
        ),
        (
            icon: "exclamationmark.triangle.fill",
            color: .red,
            text: "本 App 不保證資訊之即時性或完整性，僅為提供使用便利之第三方工具。"
        ),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 聲明條文
                    VStack(spacing: 12) {
                        ForEach(disclaimers, id: \.text) { item in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: item.icon)
                                    .font(.subheadline)
                                    .foregroundStyle(item.color)
                                    .frame(width: 20)
                                    .padding(.top, 1)
                                Text(item.text)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                        }
                    }
                    
                    // 頂部圖示
                    VStack(spacing: 8) {
                        Text("Copyright © 2026 Wesley Wang")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("版權聲明")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    CopyRightView()
}
