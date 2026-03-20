//
//  PrivacyView.swift
//  CollegeApp
//
//  Created by Wesley Wang on 2026/3/20.
//

import SwiftUI

struct PrivacyView: View {

    struct PolicySection {
        let number: String
        let title: String
        let icon: String
        let color: Color
        let paragraphs: [String]
        let bullets: [String]
    }

    private let sections: [PolicySection] = [
        .init(
            number: "一", title: "蒐集目的", icon: "scope", color: .teal,
            paragraphs: ["本 App 提供校務系統連結、課表查詢及相關校園資訊服務。"],
            bullets: []
        ),
        .init(
            number: "二", title: "蒐集之個人資料類別", icon: "person.badge.shield.checkmark.fill", color: .blue,
            paragraphs: [
                "本 App 不會蒐集、儲存或記錄使用者之學校帳號及密碼。",
                "使用者透過 App 內建 WebView 登入學校系統時，相關驗證資訊係由學校系統處理。本 App 僅透過系統提供之 HTTPCookieStorage 機制，暫時儲存登入狀態（Cookie），以維持使用期間之登入狀態。"
            ],
            bullets: []
        ),
        .init(
            number: "三", title: "個人資料利用方式", icon: "lock.doc.fill", color: .indigo,
            paragraphs: ["Cookie 僅用於："],
            bullets: ["維持登入狀態", "提供課表與校務資訊查詢功能"]
        ),
        .init(
            number: "四", title: "資料保存與安全", icon: "externaldrive.badge.checkmark", color: .orange,
            paragraphs: [
                "Cookie 屬暫時性資料，將依系統機制於期限內自動失效或刪除。",
                "使用者亦可透過登出或清除 App 資料方式移除登入狀態。"
            ],
            bullets: []
        ),
        .init(
            number: "五", title: "使用者權利", icon: "hand.raised.fill", color: .purple,
            paragraphs: ["使用者可隨時停止使用本 App，或清除資料以終止相關處理行為。"],
            bullets: []
        ),
        .init(
            number: "六", title: "資料提供", icon: "exclamationmark.shield.fill", color: .red,
            paragraphs: ["若使用者不進行登入，將無法使用部分需驗證之功能（如課表查詢）。"],
            bullets: []
        ),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // 頂部說明橫幅
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.teal)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("NKUST plus")
                                .font(.headline)
                            Text("個人資料保護聲明")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.teal.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // 各條文
                    ForEach(sections, id: \.number) { section in
                        SectionCard(section: section)
                    }

                    // 底部備注
                    Text("本聲明如有修改，將於 App 更新時一併公告。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("隱私政策")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - 條文卡片
private struct SectionCard: View {
    let section: PrivacyView.PolicySection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 標題列
            HStack(spacing: 8) {
                Image(systemName: section.icon)
                    .foregroundStyle(section.color)
                    .frame(width: 20)
                Text("\(section.number)、\(section.title)")
                    .font(.subheadline).bold()
                    .foregroundStyle(.primary)
            }

            Divider()

            // 段落文字
            VStack(alignment: .leading, spacing: 6) {
                ForEach(section.paragraphs, id: \.self) { paragraph in
                    Text(paragraph)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // 條列項目
                ForEach(section.bullets, id: \.self) { bullet in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(section.color)
                            .padding(.top, 2)
                        Text(bullet)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    PrivacyView()
}

