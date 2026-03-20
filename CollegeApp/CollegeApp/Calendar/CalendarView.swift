//
//  CalendarView.swift
//  CollegeApp
//
//  Created by Wesley Wang on 2026/3/18.
//

import SwiftUI
import PDFKit
import SwiftSoup

struct CalendarView: View {
    @State private var semester1Doc: PDFDocument?
    @State private var semester2Doc: PDFDocument?
    @State private var selectedSemester = 1
    @State private var currentYear = 0
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("載入行事曆中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("重試") { Task { await loadCalendar() } }
                        .buttonStyle(.borderedProminent)
                        .tint(.teal)
                }
                .padding()
            } else {
                VStack(spacing: 0) {
                    // 學期切換 Picker
                    Picker("學期", selection: $selectedSemester) {
                        if semester1Doc != nil {
                            Text("\(currentYear)-1").tag(1)
                        }
                        if semester2Doc != nil {
                            Text("\(currentYear)-2").tag(2)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    // 對應 PDF
                    if selectedSemester == 1, let doc = semester1Doc {
                        PDFKitView(document: doc)
                            .ignoresSafeArea(edges: .bottom)
                    } else if selectedSemester == 2, let doc = semester2Doc {
                        PDFKitView(document: doc)
                            .ignoresSafeArea(edges: .bottom)
                    } else {
                        ProgressView("載入中...").frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .navigationTitle("行事曆")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadCalendar() }
    }

    func loadCalendar() async {
        isLoading = true
        errorMessage = nil

        do {
            // Step 1：從網站抓 currentYear / currentSemester
            let pageURL = URL(string: "https://acad.nkust.edu.tw/p/412-1004-1588.php?Lang=zh-tw")!
            var request = URLRequest(url: pageURL)
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")

            let (pageData, _) = try await URLSession.shared.data(for: request)
            let html = String(data: pageData, encoding: .utf8) ?? ""

            guard let year = extractJSVar("currentYear", from: html),
                  let semester = extractJSVar("currentSemester", from: html) else {
                throw URLError(.badServerResponse)
            }

            currentYear = year
            selectedSemester = semester  // 預設顯示當前學期

            // Step 2：同時下載兩個學期
            async let doc1 = fetchPDF(year: year, semester: 1)
            async let doc2 = fetchPDF(year: year, semester: 2)

            semester1Doc = await doc1
            semester2Doc = await doc2

        } catch {
            errorMessage = "無法取得行事曆，請稍後再試"
            print("行事曆載入失敗：\(error)")
        }

        isLoading = false
    }

    // 改成不 throw，找不到就回傳 nil
    func fetchPDF(year: Int, semester: Int) async -> PDFDocument? {
        let urlString = "https://acad.nkust.edu.tw/var/file/4/1004/img/273/cal\(year)-\(semester).pdf"
        guard let pdfURL = URL(string: urlString) else { return nil }

        var request = URLRequest(url: pdfURL)
        request.setValue("https://acad.nkust.edu.tw", forHTTPHeaderField: "Referer")

        guard let (pdfData, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let document = PDFDocument(data: pdfData) else {
            return nil
        }
        return document
    }

    func extractJSVar(_ varName: String, from html: String) -> Int? {
        let pattern = "var \(varName)\\s*=\\s*(\\d+)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else { return nil }
        return Int(html[range])
    }
}

#Preview {
    CalendarView()
}
