//
//  MidtermView.swift
//  CollegeApp
//
//  Created by Wesley Wang on 2026/5/4.
//

import SwiftUI

// MARK: - Model

struct MidtermRecord: Identifiable {
    let id = UUID()
    let year: String
    let term: String
    let courseCode: String
    let name: String
    let type: String      // 必修 / 選修
    let credits: Double
    let score: String     // String，因為可能是「不開放」或數字
}

// MARK: - HTML 解析器

struct MidtermParser {

    static func parse(html: String) -> [MidtermRecord] {
        var records: [MidtermRecord] = []

        // 抓每個 <tr>
        let rowPattern = #"<tr[^>]*>([\s\S]*?)</tr>"#
        guard let rowRegex = try? NSRegularExpression(pattern: rowPattern, options: .caseInsensitive) else { return [] }

        let matches = rowRegex.matches(in: html, range: NSRange(html.startIndex..., in: html))

        for match in matches {
            guard let range = Range(match.range(at: 1), in: html) else { continue }
            let rowContent = String(html[range])

            // 用 data-label 抓對應的 td 值
            func cell(label: String) -> String {
                let pattern = #"data-label=""# + label + #""[^>]*>([\s\S]*?)</td>"#
                guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                      let m = regex.firstMatch(in: rowContent, range: NSRange(rowContent.startIndex..., in: rowContent)),
                      let r = Range(m.range(at: 1), in: rowContent) else { return "" }
                return stripTags(from: String(rowContent[r]))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let year     = cell(label: "學年")
            let term     = cell(label: "學期")
            let code     = cell(label: "課號")
            let name     = cell(label: "課程名稱")
            let type     = cell(label: "修別")
            let credStr  = cell(label: "學分")
            let scoreStr = cell(label: "期中成績")

            guard !year.isEmpty, Int(year) != nil else { continue }
            guard let credits = Double(credStr) else { continue }

            records.append(MidtermRecord(
                year: year, term: term, courseCode: code,
                name: name, type: type, credits: credits, score: scoreStr
            ))
        }

        return records
    }

    // 從 <tr> 內容中取出所有 <td> 的純文字
    private static func extractCells(from rowHTML: String) -> [String] {
        let cellPattern = #"<td[^>]*>([\s\S]*?)</td>"#
        guard let regex = try? NSRegularExpression(pattern: cellPattern, options: .caseInsensitive) else { return [] }

        let matches = regex.matches(in: rowHTML, range: NSRange(rowHTML.startIndex..., in: rowHTML))
        return matches.compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: rowHTML) else { return nil }
            let inner = String(rowHTML[range])
            // 去掉 HTML 標籤
            return stripTags(from: inner)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func stripTags(from html: String) -> String {
        let tagPattern = #"<[^>]+>"#
        let stripped = (try? NSRegularExpression(pattern: tagPattern))
            .map { $0.stringByReplacingMatches(in: html, range: NSRange(html.startIndex..., in: html), withTemplate: "") }
            ?? html

        // 解碼 HTML entities
        guard let data = stripped.data(using: .utf8) else { return stripped }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        let decoded = (try? NSAttributedString(data: data, options: options, documentAttributes: nil))
            .map { $0.string } ?? stripped
        return decoded
    }
}

// MARK: - 成績顏色輔助

private extension String {
    var midtermScoreColor: Color {
        if let score = Int(self) {
            switch score {
            case 90...100: return .green
            case 80..<90:  return .blue
            case 70..<80:  return .primary
            case 60..<70:  return .orange
            default:       return .red
            }
        }
        return .secondary  // 「不開放」等非數字
    }
}

// MARK: - 主畫面

struct MidtermView: View {
    let cookies: [HTTPCookie]

    @State private var records: [MidtermRecord] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    // 篩選
    @State private var filterType: String = "全部"
    @State private var sortByScore = false

    private var filteredRecords: [MidtermRecord] {
        var list = records
        if filterType != "全部" {
            list = list.filter { $0.type == filterType }
        }
        if sortByScore {
            list = list.sorted {
                let a = Int($0.score) ?? -1
                let b = Int($1.score) ?? -1
                return a > b
            }
        }
        return list
    }

    // 統計：只計算有數字成績的課
    private var scoredRecords: [MidtermRecord] {
        filteredRecords.filter { Int($0.score) != nil }
    }
    private var averageScore: Double? {
        guard !scoredRecords.isEmpty else { return nil }
        let sum = scoredRecords.compactMap { Int($0.score) }.reduce(0, +)
        return Double(sum) / Double(scoredRecords.count)
    }
    private var totalCredits: Double {
        filteredRecords.reduce(0) { $0 + $1.credits }
    }

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if records.isEmpty {
                emptyView
            } else {
                mainContent
            }
        }
        .navigationTitle("期中成績")
        .navigationBarTitleDisplayMode(.inline)
        .task { await fetchMidterm() }
    }

    // MARK: - 主要內容

    private var mainContent: some View {
        List {
            // 摘要卡
            Section {
                summaryCard
            }
            .listRowInsets(.init())
            .listRowBackground(Color.clear)

            // 篩選列
            Section {
                filterBar
            }
            .listRowInsets(.init(top: 0, leading: 16, bottom: 0, trailing: 16))
            .listRowBackground(Color.clear)

            // 科目列表
            Section {
                ForEach(filteredRecords) { record in
                    recordRow(record)
                }
            } header: {
                HStack {
                    Text("課程名稱").frame(maxWidth: .infinity, alignment: .leading)
                    Text("修別").frame(width: 40)
                    Text("學分").frame(width: 40)
                    Text("期中").frame(width: 50)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - 摘要卡

    private var summaryCard: some View {
        HStack(spacing: 0) {
            summaryItem(
                title: "科目數",
                value: "\(filteredRecords.count)",
                color: .teal
            )
            Divider().frame(height: 44)
            summaryItem(
                title: "總學分",
                value: String(format: "%.1f", totalCredits),
                color: .blue
            )
            Divider().frame(height: 44)
            summaryItem(
                title: "平均成績",
                value: averageScore.map { String(format: "%.1f", $0) } ?? "—",
                color: .orange
            )
        }
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func summaryItem(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.callout, design: .rounded, weight: .bold))
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 篩選列

    private var filterBar: some View {
        HStack(spacing: 8) {
            ForEach(["全部", "必修", "選修"], id: \.self) { type in
                Button {
                    withAnimation(.spring(response: 0.3)) { filterType = type }
                } label: {
                    Text(type)
                        .font(.subheadline.weight(filterType == type ? .semibold : .regular))
                        .foregroundStyle(filterType == type ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(filterType == type ? Color.teal : Color(.systemGray5))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button {
                withAnimation { sortByScore.toggle() }
            } label: {
                Label(sortByScore ? "成績" : "依序", systemImage: "arrow.up.arrow.down")
                    .font(.subheadline)
                    .foregroundStyle(sortByScore ? Color.teal : .secondary)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - 課程列

    private func recordRow(_ record: MidtermRecord) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.name)
                    .font(.subheadline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(record.courseCode)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(record.type)
                .font(.caption2.weight(.medium))
                .foregroundStyle(record.type == "必修" ? Color.blue : Color.purple)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background((record.type == "必修" ? Color.blue : Color.purple).opacity(0.1))
                .clipShape(Capsule())
                .frame(width: 46)

            Text(String(format: "%.1f", record.credits))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36)

            Text(record.score)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(record.score.midtermScoreColor)
                .frame(width: 50)
        }
        .padding(.vertical, 4)
    }

    // MARK: - 輔助 Views

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("載入期中成績中…").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("目前沒有期中成績資料")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("重試") {
                Task { await fetchMidterm() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 網路請求

    func fetchMidterm() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        guard let url = URL(string: "https://stdsys.nkust.edu.tw/student/Score/MidTerm") else { return }

        var request = URLRequest(url: url)
        HTTPCookie.requestHeaderFields(with: cookies).forEach {
            request.setValue($1, forHTTPHeaderField: $0)
        }

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let html = String(data: data, encoding: .utf8) ?? ""
            let parsed = MidtermParser.parse(html: html)

            await MainActor.run {
                records = parsed
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "網路錯誤：\(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        MidtermView(cookies: [])
    }
}
