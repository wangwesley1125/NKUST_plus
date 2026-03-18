//
//  ScoreView.swift
//  CollegeApp
//
//  Created by 王耀偉 on 2026/3/14.
//

import SwiftUI
import PDFKit

struct ScoreView: View {
    let cookies: [HTTPCookie]

    @State private var semesters: [Semester] = []
    @State private var selectedYM = ""
    @State private var verificationToken = ""
    @State private var pdfDocument: PDFDocument?
    @State private var isLoadingSemesters = true
    @State private var isLoadingPDF = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 學期選擇列
                HStack {
                    if isLoadingSemesters {
                        ProgressView("載入學期中...")
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("學期")
                            .foregroundStyle(.secondary)
                        
                        Picker("學期", selection: $selectedYM) {
                            ForEach(semesters) { sem in
                                Text(sem.displayName).tag(sem.ym)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedYM) {
                            Task { await fetchPDF() }
                        }
                        
                        Spacer()
                    }
                }
                .padding()
                .background(.bar)
                
                Divider()
                
                // 內容區
                ZStack {
                    if isLoadingPDF {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("載入成績單中...").foregroundStyle(.secondary)
                        }
                    } else if let doc = pdfDocument {
                        PDFKitView(document: doc)
                    } else if let error = errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundStyle(.orange)
                            Text(error)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("重試") { Task { await fetchSemestersAndToken() } }
                                .buttonStyle(.bordered)
                        }
                        .padding()
                    } else {
                        Text("請選擇學期後按查詢")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("我的成績")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await fetchSemestersAndToken()
            }
        }
    }

    func generateSemesters() -> [Semester] {
        // 目前民國年 = 西元年 - 1911
        let currentYear = Calendar.current.component(.year, from: Date()) - 1911
        var result: [Semester] = []
        
        for year in stride(from: currentYear, through: 110, by: -1) {
            result.append(Semester(ym: "\(year)-2", displayName: "\(year)-2"))
            result.append(Semester(ym: "\(year)-1", displayName: "\(year)-1"))
        }
        return result
    }
    
    // MARK: - Step 1：取得學期列表 + Token

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
//            let (data, _) = try await URLSession.shared.data(for: request)
//            let html = String(data: data, encoding: .utf8) ?? ""

            let (data, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let html = String(data: data, encoding: .utf8) ?? ""

            // Debug
            print("🌐 狀態碼：\(statusCode)")
            print("🌐 HTML 長度：\(html.count)")
            print("🌐 HTML 前 500 字：\n\(html.prefix(500))")
            
            // 從 JS 解析學期，取代 generateSemesters()
            let jsPattern = #""(\d{3}-\d)""#
            var parsedFromJS: [Semester] = []
            if let jsRegex = try? NSRegularExpression(pattern: jsPattern) {
                let jsMatches = jsRegex.matches(in: html, range: NSRange(html.startIndex..., in: html))
                // 用 Set 去重複，再排序（最新學期排前面）
                let ymSet = jsMatches.compactMap { match -> String? in
                    guard let range = Range(match.range(at: 1), in: html) else { return nil }
                    return String(html[range])
                }
                let unique = Array(Set(ymSet)).sorted().reversed()
                parsedFromJS = unique.map { Semester(ym: $0, displayName: $0) }
            }
            
            print("從 JS 解析學期：\(parsedFromJS.map { $0.ym })")
            
            if let optionRange = html.range(of: "<option") {
                let fromOption = html[optionRange.lowerBound...]
                print("📋 Option HTML：\n\(fromOption.prefix(300))")
            } else {
                print("❌ 找不到任何 <option 標籤")
            }

            // 同時印出 HTML 中間段，看看選單在哪
            let midStart = html.index(html.startIndex, offsetBy: min(5000, html.count))
            let midEnd = html.index(midStart, offsetBy: min(1000, html.distance(from: midStart, to: html.endIndex)))
            print("📋 HTML 中間段：\n\(html[midStart..<midEnd])")
            
            // 解析學期下拉選單
            let semesterPattern = #"<option[^>]*value="(\d{4})"[^>]*>(.*?)</option>"#
            let semesterRegex = try NSRegularExpression(pattern: semesterPattern)
            let semesterMatches = semesterRegex.matches(in: html, range: NSRange(html.startIndex..., in: html))

            let parsedSemesters: [Semester] = semesterMatches.compactMap { match in
                guard let ymRange = Range(match.range(at: 1), in: html),
                      let nameRange = Range(match.range(at: 2), in: html) else { return nil }
                return Semester(
                    ym: String(html[ymRange]),
                    displayName: String(html[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }

            // 解析 __RequestVerificationToken（藏在 hidden input 或 meta 裡）
            // 先試 <input type="hidden" name="__RequestVerificationToken" value="...">
            var token = ""
            let inputPattern = #"name="__RequestVerificationToken"[^>]*value="([^"]+)""#
            //let metaPattern = #"name="__RequestVerificationToken"[^/]*/>\s*<input[^>]*value="([^"]+)""#
            if token.isEmpty {
                let metaTokenPattern = #"<meta name="__RequestVerificationToken" content="([^"]+)""#
                if let metaRegex = try? NSRegularExpression(pattern: metaTokenPattern),
                   let match = metaRegex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                   let tokenRange = Range(match.range(at: 1), in: html) {
                    token = String(html[tokenRange])
                }
            }

            if let inputRegex = try? NSRegularExpression(pattern: inputPattern),
               let match = inputRegex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let tokenRange = Range(match.range(at: 1), in: html) {
                token = String(html[tokenRange])
            }

            // 備用：從 meta 標籤取
            if token.isEmpty {
                let metaTokenPattern = #"<meta name="__RequestVerificationToken" content="([^"]+)""#
                if let metaRegex = try? NSRegularExpression(pattern: metaTokenPattern),
                   let match = metaRegex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                   let tokenRange = Range(match.range(at: 1), in: html) {
                    token = String(html[tokenRange])
                }
            }

            print("✅ 取得 Token：\(token.prefix(20))...")
            print("✅ 學期數量：\(parsedSemesters.count)")
            print("✅ 學期列表：\(parsedSemesters.map { $0.ym })")

            await MainActor.run {
                semesters = parsedFromJS
                selectedYM = parsedFromJS.first?.ym ?? ""
                verificationToken = token
                isLoadingSemesters = false
            }

            if !semesters.isEmpty {
                await fetchPDF()
            }

        } catch {
            await MainActor.run {
                errorMessage = "無法載入頁面：\(error.localizedDescription)"
                isLoadingSemesters = false
            }
        }
    }

    // MARK: - Step 2：取得 PDF

    func fetchPDF() async {
        guard !selectedYM.isEmpty else { return }

        await MainActor.run {
            isLoadingPDF = true
            errorMessage = nil
            pdfDocument = nil
        }

        // 組合 URL（含 token）
        let ymForAPI = selectedYM.replacingOccurrences(of: "-", with: "")

        var components = URLComponents(string: "https://stdsys.nkust.edu.tw/student/Score/SingleSemesterTranscript/PrintTranscript")!
        components.queryItems = [
            URLQueryItem(name: "YM", value: ymForAPI),  // ← 用轉換後的
            URLQueryItem(name: "ShowRank", value: "true"),
            URLQueryItem(name: "__RequestVerificationToken", value: verificationToken),
            URLQueryItem(name: "ShowRank", value: "false")
        ]

        guard let url = components.url else { return }

        var request = URLRequest(url: url)
        HTTPCookie.requestHeaderFields(with: cookies).forEach {
            request.setValue($1, forHTTPHeaderField: $0)
        }

        // 加上 Referer（部分後端會驗證）
        request.setValue(
            "https://stdsys.nkust.edu.tw/student/Score/SingleSemesterTranscript",
            forHTTPHeaderField: "Referer"
        )

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let contentType = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type") ?? ""

            print("📄 Content-Type：\(contentType)，資料大小：\(data.count) bytes")

            await MainActor.run {
                if let doc = PDFDocument(data: data) {
                    pdfDocument = doc
                } else {
                    // 若還是 HTML，token 可能過期，重新取得
                    let htmlPreview = String(data: data.prefix(500), encoding: .utf8) ?? ""
                    print("⚠️ 無法解析 PDF，回應前 500 字：\n\(htmlPreview)")
                    errorMessage = "無法取得成績單，Token 可能已過期，請重試"
                }
                isLoadingPDF = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "網路錯誤：\(error.localizedDescription)"
                isLoadingPDF = false
            }
        }
    }
}

// MARK: - PDFKit 包裝

//struct PDFKitView: UIViewRepresentable {
//    let document: PDFDocument
//
//    func makeUIView(context: Context) -> PDFView {
//        let pdfView = PDFView()
//        pdfView.autoScales = true
//        pdfView.displayMode = .singlePageContinuous
//        pdfView.displayDirection = .vertical
//        pdfView.document = document
//        return pdfView
//    }
//
//    func updateUIView(_ uiView: PDFView, context: Context) {
//        uiView.document = document
//    }
//}

// MARK: - Model

struct Semester: Identifiable {
    let id = UUID()
    let ym: String
    let displayName: String
}

#Preview {
    ScoreView(cookies: [])
}
