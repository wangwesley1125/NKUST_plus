//
//  MidtermView.swift
//  CollegeApp
//
//  Created by Wesley Wang on 2026/5/4.
//

import SwiftUI
 
// MARK: - Model（期中、當學期共用）
 
struct ScoreRecord: Identifiable {
    let id = UUID()
    let year: String
    let term: String
    let courseCode: String
    let name: String
    let type: String      // 必修 / 選修
    let credits: Double
    let score: String     // String，因為可能是「不開放」或數字
}
 
// MARK: - HTML 解析器（標籤無關版）
 
struct ScoreParser {
 
    /// - Parameter scoreLabels: 成績欄候選的 data-label，依序嘗試，挑第一個存在的。
    ///   例如期中 ["期中成績"]，當學期 ["學期成績", "成績", "當學期成績", "期末成績"]。
    static func parse(html: String, scoreLabels: [String]) -> [ScoreRecord] {
        var records: [ScoreRecord] = []
 
        let rowPattern = #"<tr[^>]*>([\s\S]*?)</tr>"#
        guard let rowRegex = try? NSRegularExpression(pattern: rowPattern, options: .caseInsensitive) else { return [] }
 
        let matches = rowRegex.matches(in: html, range: NSRange(html.startIndex..., in: html))
 
        for match in matches {
            guard let range = Range(match.range(at: 1), in: html) else { continue }
            let rowContent = String(html[range])
 
            // 把整列的 td 收成 [data-label: 純文字]
            let cells = cellDictionary(from: rowContent)
 
            let year    = cells["學年"] ?? ""
            let term    = cells["學期"] ?? ""
            let code    = cells["課號"] ?? ""
            let name    = cells["課程名稱"] ?? ""
            let type    = cells["修別"] ?? ""
            let credStr = cells["學分"] ?? ""
 
            // 成績欄 label 不確定 → 依候選清單挑第一個「存在」的（就算值是空字串也算）
            let scoreKey = scoreLabels.first { cells.keys.contains($0) }
            let scoreStr = scoreKey.flatMap { cells[$0] } ?? ""
 
            guard !year.isEmpty, Int(year) != nil else { continue }
            guard let credits = Double(credStr) else { continue }
 
            records.append(ScoreRecord(
                year: year, term: term, courseCode: code,
                name: name, type: type, credits: credits, score: scoreStr
            ))
        }
 
        return records
    }
 
    /// 把一個 <tr> 內所有 <td data-label="X">value</td> 收成字典
    private static func cellDictionary(from rowHTML: String) -> [String: String] {
        var dict: [String: String] = [:]
        let pattern = #"data-label=["']([^"']+)["'][^>]*>([\s\S]*?)</td>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return dict }
 
        let matches = regex.matches(in: rowHTML, range: NSRange(rowHTML.startIndex..., in: rowHTML))
        for m in matches {
            guard let lr = Range(m.range(at: 1), in: rowHTML),
                  let vr = Range(m.range(at: 2), in: rowHTML) else { continue }
            let label = String(rowHTML[lr])
            let value = stripTags(from: String(rowHTML[vr]))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            dict[label] = value
        }
        return dict
    }
 
    // 去掉標籤 + 解碼 HTML entity
    private static func stripTags(from html: String) -> String {
        let tagPattern = #"<[^>]+>"#
        let stripped = (try? NSRegularExpression(pattern: tagPattern))
            .map { $0.stringByReplacingMatches(in: html, range: NSRange(html.startIndex..., in: html), withTemplate: "") }
            ?? html
        return decodeEntities(stripped)
    }
 
    /// 解碼 HTML entity：先處理數字實體（&#xHHHH; / &#DDDD;，學校的中文都是這種），再處理具名實體。
    private static func decodeEntities(_ input: String) -> String {
        // 1) 數字實體（十六進位、十進位）
        var result = input
        let pattern = #"&#(x[0-9A-Fa-f]+|[0-9]+);"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let ns = result as NSString
            let matches = regex.matches(in: result, range: NSRange(location: 0, length: ns.length))
            if !matches.isEmpty {
                var rebuilt = ""
                var lastEnd = 0
                for m in matches {
                    rebuilt += ns.substring(with: NSRange(location: lastEnd, length: m.range.location - lastEnd))
                    let token = ns.substring(with: m.range(at: 1))
                    let value: UInt32? = (token.first == "x" || token.first == "X")
                        ? UInt32(token.dropFirst(), radix: 16)
                        : UInt32(token, radix: 10)
                    if let v = value, let scalar = Unicode.Scalar(v) {
                        rebuilt += String(scalar)
                    } else {
                        rebuilt += ns.substring(with: m.range)   // 解不出來就保留原文
                    }
                    lastEnd = m.range.location + m.range.length
                }
                rebuilt += ns.substring(from: lastEnd)
                result = rebuilt
            }
        }
 
        // 2) 具名實體（&amp; 放最後，避免二次解碼）
        return result
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&lt;",   with: "<")
            .replacingOccurrences(of: "&gt;",   with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&amp;",  with: "&")
    }
}
 
// MARK: - 成績顏色輔助
 
private extension String {
    var scoreColor: Color {
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
 
// MARK: - 容器：上方 tab bar
 
struct MidtermView: View {
    let cookies: [HTTPCookie]
 
    @State private var tab = 0  // 0 = 期中，1 = 當學期
 
    var body: some View {
        VStack(spacing: 0) {
            Picker("成績類別", selection: $tab) {
                Text("期中成績").tag(0)
                Text("當學期").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)
 
            if tab == 0 {
                ScoreListView(
                    cookies: cookies,
                    endpoint: "https://stdsys.nkust.edu.tw/student/Score/MidTerm",
                    scoreLabels: ["期中成績"],
                    scoreColumnTitle: "期中",
                    emptyText: "目前無期中成績"
                )
                .id("midterm")
            } else {
                ScoreListView(
                    cookies: cookies,
                    endpoint: "https://stdsys.nkust.edu.tw/student/Score/PresentSemester",
                    scoreLabels: ["學期成績", "成績", "當學期成績", "期末成績"],
                    scoreColumnTitle: "學期",
                    emptyText: "目前無當學期成績"
                )
                .id("semester")
            }
        }
        .navigationTitle("本學期成績")
        .navigationBarTitleDisplayMode(.inline)
    }
}
 
// MARK: - 共用列表（期中 / 當學期都用這個）
 
struct ScoreListView: View {
    let cookies: [HTTPCookie]
    let endpoint: String          // 要抓的網址
    let scoreLabels: [String]     // 成績欄候選 data-label
    let scoreColumnTitle: String  // 表頭顯示文字，例如「期中」「學期」
    let emptyText: String         // 無資料時顯示的文字
 
    @State private var records: [ScoreRecord] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
 
    // 篩選
    @State private var filterType: String = "全部"
    @State private var sortByScore = false
 
    private var filteredRecords: [ScoreRecord] {
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
    private var scoredRecords: [ScoreRecord] {
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
        .task { await fetch() }
    }
 
    // MARK: - 主要內容
 
    private var mainContent: some View {
        List {
            Section {
                summaryCard
            }
            .listRowInsets(.init())
            .listRowBackground(Color.clear)
 
            Section {
                filterBar
            }
            .listRowInsets(.init(top: 0, leading: 16, bottom: 0, trailing: 16))
            .listRowBackground(Color.clear)
 
            Section {
                ForEach(filteredRecords) { record in
                    recordRow(record)
                }
            } header: {
                HStack {
                    Text("課程名稱").frame(maxWidth: .infinity, alignment: .leading)
                    Text("修別").frame(width: 40)
                    Text("學分").frame(width: 40)
                    Text(scoreColumnTitle).frame(width: 50)
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
            summaryItem(title: "科目數", value: "\(filteredRecords.count)", color: .teal)
            Divider().frame(height: 44)
            summaryItem(title: "總學分", value: String(format: "%.1f", totalCredits), color: .blue)
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
 
    private func recordRow(_ record: ScoreRecord) -> some View {
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
 
            Text(record.score.isEmpty ? "—" : record.score)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(record.score.scoreColor)
                .frame(width: 50)
        }
        .padding(.vertical, 4)
    }
 
    // MARK: - 輔助 Views
 
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("載入中…").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
 
    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(emptyText)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
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
                Task { await fetch() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
 
    // MARK: - 網路請求
 
    func fetch() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
 
        guard let url = URL(string: endpoint) else { return }
 
        var request = URLRequest(url: url)
        HTTPCookie.requestHeaderFields(with: cookies).forEach {
            request.setValue($1, forHTTPHeaderField: $0)
        }
 
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let html = String(data: data, encoding: .utf8) ?? ""
            let parsed = ScoreParser.parse(html: html, scoreLabels: scoreLabels)
 
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
