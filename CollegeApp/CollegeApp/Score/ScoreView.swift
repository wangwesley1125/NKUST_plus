//
//  ScoreView.swift
//  CollegeApp
//
//  Created by Wesley Wang on 2026/3/14.
//

import SwiftUI
import PDFKit
 
// MARK: - Models
 
struct CourseRecord: Identifiable {
    let id = UUID()
    let name: String
    let type: String       // 必修 / 選修
    let credits: Double
    let score: Int
}
 
struct TranscriptData {
    var semester: String = ""
    var studentID: String = ""
    var studentName: String = ""
    var department: String = ""
    var classInfo: String = ""
    var courses: [CourseRecord] = []
    var earnedCredits: Double = 0
    var requiredCredits: Double = 0
    var academicScore: Double = 0
    var conductScore: Double = 0
    var classRank: String = ""
}
 
// MARK: - PDF 文字解析器
 
struct TranscriptParser {
 
    static func parse(from document: PDFDocument) -> TranscriptData {
        var fullText = ""
        for i in 0..<document.pageCount {
            fullText += (document.page(at: i)?.string ?? "") + "\n"
        }
        return parse(text: fullText)
    }
 
    static func parse(text: String) -> TranscriptData {
        var data = TranscriptData()
        let lines = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
 
        for line in lines {
            // 學期
//            if line.contains("學年度") && line.contains("學期") {
//                data.semester = line
//                    .replacingOccurrences(of: "成績通知單", with: "")
//                    .trimmingCharacters(in: .whitespaces)
//            }
 
            // 科系
            if line.contains("科系所：") {
                if let range = line.range(of: "科系所：") {
                    let after = line[range.upperBound...]
                    // 取到下一個中文冒號前
                    let dept = after.components(separatedBy: "班 級")[0]
                    data.department = dept
                        .replacingOccurrences(of: "班 級：", with: "")
                        .trimmingCharacters(in: .whitespaces)
                }
                if let range = line.range(of: "班 級：") {
                    data.classInfo = String(line[range.upperBound...])
                        .trimmingCharacters(in: .whitespaces)
                }
            }
 
            // 學號 / 姓名
            if line.contains("學 號：") {
                let parts = line.components(separatedBy: "姓 名：")
                if parts.count == 2 {
                    data.studentID = parts[0]
                        .replacingOccurrences(of: "學 號：", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    data.studentName = parts[1].trimmingCharacters(in: .whitespaces)
                }
            }
 
            // 科目行：名稱 必修/選修 學分 成績
            if let course = parseCourse(from: line) {
                data.courses.append(course)
            }
 
            // 摘要欄位
            if line.contains("修習學分：") {
                data.requiredCredits = extractDouble(after: "修習學分：", in: line) ?? 0
            }
            if line.contains("實得學分：") {
                data.earnedCredits = extractDouble(after: "實得學分：", in: line) ?? 0
            }
            if line.contains("學業成績：") {
                data.academicScore = extractDouble(after: "學業成績：", in: line) ?? 0
            }
            if line.contains("操行成績：") {
                data.conductScore = extractDouble(after: "操行成績：", in: line) ?? 0
            }
            if line.contains("班 排 名：") || line.contains("班排名：") {
                if let range = line.range(of: "：") {
                    data.classRank = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                }
            }
        }
 
        return data
    }
 
    // MARK: 解析單一科目行
    // 格式：<課程名稱> <必修|選修> <學分> <成績>
    private static func parseCourse(from line: String) -> CourseRecord? {
        let pattern = #"^(.+?)\s+(必修|選修)\s+(\d+\.?\d*)\s+(\d{1,3})$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges == 5 else { return nil }
 
        func capture(_ i: Int) -> String? {
            guard let r = Range(match.range(at: i), in: line) else { return nil }
            return String(line[r])
        }
 
        guard let name    = capture(1),
              let type    = capture(2),
              let credStr = capture(3),
              let scoreStr = capture(4),
              let credits = Double(credStr),
              let score   = Int(scoreStr) else { return nil }
 
        return CourseRecord(name: name, type: type, credits: credits, score: score)
    }
 
    private static func extractDouble(after prefix: String, in line: String) -> Double? {
        guard let range = line.range(of: prefix) else { return nil }
        let rest = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
        // 取第一個數字片段
        let numStr = rest.components(separatedBy: .whitespaces).first ?? rest
        return Double(numStr)
    }
}
 
// MARK: - 成績顏色輔助
 
private extension Int {
    var scoreColor: Color {
        switch self {
        case 90...100: return .green
        case 80..<90:  return .blue
        case 70..<80:  return .primary
        case 60..<70:  return .orange
        default:       return .red
        }
    }
}
 
// MARK: - 主畫面
 
struct ScoreView: View {
    let cookies: [HTTPCookie]
 
    @State private var semesters: [Semester] = []
    @State private var selectedYM = ""
    @State private var verificationToken = ""
    @State private var transcriptData: TranscriptData?
    @State private var isLoadingSemesters = true
    @State private var isLoadingData = false
    @State private var errorMessage: String?
 
    // 篩選狀態
    @State private var filterType: String = "全部"   // 全部 / 必修 / 選修
    @State private var sortByScore = false
 
    private var filteredCourses: [CourseRecord] {
        guard let data = transcriptData else { return [] }
        var list = data.courses
        if filterType != "全部" {
            list = list.filter { $0.type == filterType }
        }
        return sortByScore ? list.sorted { $0.score > $1.score } : list
    }
 
    var body: some View {
        NavigationStack {
            Group {
                if isLoadingSemesters {
                    loadingView("載入學期中…")
                } else if isLoadingData {
                    loadingView("取得成績中…")
                } else if let error = errorMessage {
                    errorView(error)
                } else if let data = transcriptData {
                    mainContent(data)
                } else {
                    Text("請選擇學期")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("我的成績")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { semesterPicker }
            .task { await fetchSemestersAndToken() }
        }
    }
 
    // MARK: - 學期選擇工具列
 
    @ToolbarContentBuilder
    private var semesterPicker: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            if !isLoadingSemesters && !semesters.isEmpty {
                Menu {
                    ForEach(semesters) { sem in
                        Button(sem.displayName) {
                            selectedYM = sem.ym
                            Task { await fetchPDF() }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(semesters.first(where: { $0.ym == selectedYM })?.displayName ?? "選擇學期")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minWidth: 110)
            }
        }
    }
 
    // MARK: - 主要內容
 
    @ViewBuilder
    private func mainContent(_ data: TranscriptData) -> some View {
        List {
            // 學生資訊卡
            Section {
                studentInfoCard(data)
            }
            .listRowInsets(.init())
            .listRowBackground(Color.clear)
 
            // 成績摘要卡
            Section {
                summaryCard(data)
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
                ForEach(filteredCourses) { course in
                    courseRow(course)
                }
            } header: {
                HStack {
                    Text("科目").frame(maxWidth: .infinity, alignment: .leading)
                    Text("修別").frame(width: 40)
                    Text("學分").frame(width: 40)
                    Text("成績").frame(width: 44)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            }
        }
        .listStyle(.insetGrouped)
    }
 
    // MARK: - 學生資訊卡
 
    private func studentInfoCard(_ data: TranscriptData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(data.studentName)
                        .font(.title2.weight(.bold))
                    Text(data.studentID)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.teal)
            }
 
            Divider()
 
            HStack(spacing: 0) {
                infoChip(icon: "building.2", text: data.department)
                Spacer()
                infoChip(icon: "person.3", text: data.classInfo)
            }
 
            Text(data.semester)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
 
    // MARK: - 成績摘要卡
 
    private func summaryCard(_ data: TranscriptData) -> some View {
        HStack(spacing: 0) {
            summaryItem(title: "學業成績", value: String(format: "%.2f", data.academicScore), color: .blue)
            Divider().frame(height: 44)
            summaryItem(title: "操行成績", value: String(format: "%.2f", data.conductScore), color: .purple)
            Divider().frame(height: 44)
            summaryItem(title: "實得學分", value: String(format: "%.0f", data.earnedCredits), color: .green)
            Divider().frame(height: 44)
            summaryItem(title: "班級排名", value: data.classRank, color: .orange)
        }
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
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
                        .background(filterType == type ? Color(Color.teal) : Color(.systemGray5))
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
                    .foregroundStyle(sortByScore ? Color(Color.teal) : .secondary)
            }
        }
        .padding(.vertical, 6)
    }
 
    // MARK: - 科目列
 
    private func courseRow(_ course: CourseRecord) -> some View {
        HStack(spacing: 8) {
            // 科目名稱
            Text(course.name)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
 
            // 修別標籤
            Text(course.type)
                .font(.caption2.weight(.medium))
                .foregroundStyle(course.type == "必修" ? Color.blue : Color.purple)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background((course.type == "必修" ? Color.blue : Color.purple).opacity(0.1))
                .clipShape(Capsule())
                .frame(width: 46)
 
            // 學分
            Text(String(format: "%.1f", course.credits))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36)
 
            // 成績
            Text("\(course.score)")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(course.score.scoreColor)
                .frame(width: 44)
        }
        .padding(.vertical, 2)
    }
 
    // MARK: - 輔助 Views
    private func infoChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
 
    private func loadingView(_ message: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(message).foregroundStyle(.secondary)
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
                Task { await fetchSemestersAndToken() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
 
    // MARK: - 網路請求
    func fetchSemestersAndToken() async {
        await MainActor.run {
            isLoadingSemesters = true
            errorMessage = nil
        }
 
        guard let url = URL(string: "https://stdsys.nkust.edu.tw/student/Score/SingleSemesterTranscript") else { return }
 
        var request = URLRequest(url: url)
        HTTPCookie.requestHeaderFields(with: cookies).forEach {
            request.setValue($1, forHTTPHeaderField: $0)
        }
 
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let html = String(data: data, encoding: .utf8) ?? ""
 
            // 解析學期（從 JS 字串中取出）
            let jsPattern = #""(\d{3}-\d)""#
            var parsedSemesters: [Semester] = []
            if let regex = try? NSRegularExpression(pattern: jsPattern) {
                let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
                let ymSet = matches.compactMap { match -> String? in
                    guard let r = Range(match.range(at: 1), in: html) else { return nil }
                    return String(html[r])
                }
                parsedSemesters = Array(Set(ymSet)).sorted().reversed()
                    .map { Semester(ym: $0, displayName: $0) }
            }
 
            // 解析 Token
            var token = ""
            let inputPattern = #"name="__RequestVerificationToken"[^>]*value="([^"]+)""#
            if let regex = try? NSRegularExpression(pattern: inputPattern),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let r = Range(match.range(at: 1), in: html) {
                token = String(html[r])
            }
 
            await MainActor.run {
                semesters = parsedSemesters
                selectedYM = parsedSemesters.first?.ym ?? ""
                verificationToken = token
                isLoadingSemesters = false
            }
 
            if !parsedSemesters.isEmpty {
                await fetchPDF()
            }
 
        } catch {
            await MainActor.run {
                errorMessage = "無法載入頁面：\(error.localizedDescription)"
                isLoadingSemesters = false
            }
        }
    }
 
    func fetchPDF() async {
        guard !selectedYM.isEmpty else { return }
 
        await MainActor.run {
            isLoadingData = true
            errorMessage = nil
            transcriptData = nil
        }
 
        let ymForAPI = selectedYM.replacingOccurrences(of: "-", with: "")
        var components = URLComponents(string: "https://stdsys.nkust.edu.tw/student/Score/SingleSemesterTranscript/PrintTranscript")!
        components.queryItems = [
            URLQueryItem(name: "YM", value: ymForAPI),
            URLQueryItem(name: "ShowRank", value: "true"),
            URLQueryItem(name: "__RequestVerificationToken", value: verificationToken),
            URLQueryItem(name: "ShowRank", value: "false")
        ]
 
        guard let url = components.url else { return }
 
        var request = URLRequest(url: url)
        HTTPCookie.requestHeaderFields(with: cookies).forEach {
            request.setValue($1, forHTTPHeaderField: $0)
        }
        request.setValue(
            "https://stdsys.nkust.edu.tw/student/Score/SingleSemesterTranscript",
            forHTTPHeaderField: "Referer"
        )
 
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
 
            await MainActor.run {
                if let doc = PDFDocument(data: data) {
                    // 解析 PDF 文字，不顯示原始 PDF
                    transcriptData = TranscriptParser.parse(from: doc)
                } else {
                    errorMessage = "無法取得成績單，請重試"
                }
                isLoadingData = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "網路錯誤：\(error.localizedDescription)"
                isLoadingData = false
            }
        }
    }
}
 
// MARK: - Model
 
struct Semester: Identifiable {
    let id = UUID()
    let ym: String
    let displayName: String
}
 
#Preview {
    ScoreView(cookies: [])
}
