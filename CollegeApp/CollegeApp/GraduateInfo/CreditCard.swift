//
//  CreditCard.swift
//  CollegeApp
//
//  Created by Wesley on 2026/10/1.
//

import SwiftUI
 
// MARK: - 首頁卡片
struct CreditCard: View {
    let status: GraduationStatus
    let cookies: [HTTPCookie]

    private var earned: Int   { status.total?.earned ?? 0 }
    private var required: Int { max(status.total?.required ?? 0, 1) }
    private var progress: Double { min(Double(earned) / Double(required), 1) }
    private var unmetCount: Int { status.unmetItems.count }

    /// 還有未通過項目時用橘色提醒，全部通過用 teal
    private var accent: Color { unmetCount > 0 ? .orange : .teal }

    var body: some View {
        NavigationLink {
            CreditDetailView(status: status, cookies: cookies)
        } label: {
            VStack(alignment: .leading, spacing: 12) {

                // 標題列
                HStack {
                    Label("畢業學分", systemImage: "graduationcap.fill")
                        .font(.subheadline.bold())
                        .foregroundColor(.teal)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.bold())
                        .foregroundColor(.secondary)
                }

                // 學分數字 + 狀態
                HStack(alignment: .firstTextBaseline) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(earned)")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("/ \(required) 學分")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    statusBadge
                }

                // 進度條
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(accent.opacity(0.15))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [accent.opacity(0.7), accent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 8)
            }
            .padding()
            .background(Color(.systemGray6).opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: 狀態膠囊
    @ViewBuilder
    private var statusBadge: some View {
        if unmetCount > 0 {
            Label("\(unmetCount) 項未通過", systemImage: "exclamationmark.circle.fill")
                .font(.caption.bold())
                .foregroundColor(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.orange.opacity(0.12))
                .clipShape(Capsule())
        } else if status.isAllPassed {
            Label("已達畢業標準", systemImage: "checkmark.seal.fill")
                .font(.caption.bold())
                .foregroundColor(.green)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.green.opacity(0.12))
                .clipShape(Capsule())
        }
    }
}
 
// MARK: - 詳細頁
struct CreditDetailView: View {
    let status: GraduationStatus
    let cookies: [HTTPCookie]
    
    var body: some View {
        List {
            // 尚未通過
            if !status.unmetItems.isEmpty {
                Section("尚未通過") {
                    ForEach(status.unmetItems) { item in
                        CreditRow(item: item)
                    }
                }
            }
 
            // 學分總覽
            if !status.summary.isEmpty {
                Section("修課學分結果預覽") {
                    OutlineGroup(status.summary, children: \.childrenOrNil) { item in
                        CreditRow(item: item)
                    }
                }
            }
 
            // 課群比對
            if !status.groups.isEmpty {
                Section("課規課群比對結果") {
                    OutlineGroup(status.groups, children: \.childrenOrNil) { item in
                        CreditRow(item: item)
                    }
                }
            }
 
            Section {
                Text("結果依學校最後審查為準，僅供參考。")
                    .font(.footnote)
                    .foregroundColor(.pink)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("修課學分狀況")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    CoursePlanView(cookies: cookies)
                } label: {
                    Label("課程規劃", systemImage: "tablecells")
                }
            }
        }
    }
}
 
// MARK: - 單列
private struct CreditRow: View {
    let item: CreditItem
 
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.status.symbol)
                .foregroundColor(item.status.color)
 
            Text(item.name)
                .font(.subheadline)
                .lineLimit(2)
 
            Spacer()
 
            if let detail {
                Text(detail)
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(item.status == .failed ? .red : .secondary)
            }
        }
        .padding(.vertical, 2)
    }
 
    /// 有學分要求就顯示學分；學分要求是 0 但有課程數（例如體育）就顯示課程數
    private var detail: String? {
        if let r = item.required, let e = item.earned, r > 0 {
            return "\(e) / \(r) 學分"
        }
        if let r = item.requiredCourses, let p = item.passedCourses {
            return "\(p) / \(r) 門"
        }
        if let e = item.earned, e > 0 {
            return "\(e) 學分"
        }
        return nil
    }
}
 
// MARK: - 狀態樣式
private extension CreditItem.Status {
    var symbol: String {
        switch self {
        case .passed:      return "checkmark.circle.fill"
        case .conditional: return "checkmark.square.fill"
        case .failed:      return "xmark.circle.fill"
        case .unknown:     return "circle"
        }
    }
 
    var color: Color {
        switch self {
        case .passed:      return .blue
        case .conditional: return .orange
        case .failed:      return .red
        case .unknown:     return .secondary
        }
    }
}
 
// MARK: - Preview
#Preview {
    let sample = GraduationStatus(
        groups: [
            CreditItem(name: "校共同必修課程", status: .passed, required: 12, earned: 12,
                       requiredCourses: nil, passedCourses: nil, children: []),
            CreditItem(name: "通識課程", status: .passed, required: 16, earned: 16,
                       requiredCourses: nil, passedCourses: nil, children: [
                CreditItem(name: "科技與數位知能", status: .failed, required: nil, earned: 0,
                           requiredCourses: 1, passedCourses: 0, children: [])
            ]),
            CreditItem(name: "系專業課程", status: .failed, required: 0, earned: 96,
                       requiredCourses: nil, passedCourses: nil, children: [
                CreditItem(name: "選修", status: .failed, required: 37, earned: 35,
                           requiredCourses: nil, passedCourses: nil, children: [])
            ])
        ],
        summary: [
            CreditItem(name: "畢業審查學分數", status: .failed, required: 128, earned: 130,
                       requiredCourses: nil, passedCourses: nil, children: [])
        ]
    )
    return NavigationStack {
        VStack {
            CreditCard(status: sample, cookies: [])
            Spacer()
        }
        .padding()
    }
}
