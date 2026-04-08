//
//  SchoolSertifacate.swift
//  CollegeApp
//
//  Created by Wesley Wang on 2026/3/19.
//

import SwiftUI
import PDFKit

// MARK: - 學校新系統有分中文和英文版
enum CertificateLanguage {
    case chinese, english
    
    var url: URL {
        switch self {
        case .chinese:
            return URL(string: "https://stdsys.nkust.edu.tw/student/Doc/Status/ChinesePDF")!
        case .english:
            return URL(string: "https://stdsys.nkust.edu.tw/student/Doc/Status/EnglishPDF")!
        }
    }
}

struct SchoolSertifacate: View {
    let cookies: [HTTPCookie]
    
    @State private var selectedLanguage: CertificateLanguage = .chinese
    @State private var pdfDocument: PDFDocument?
    @State private var isLoading = true
    @State private var isSwitching = false // 切換中英文版
    @State private var errorMessage: String?
    
    @State private var pdfData: Data?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("載入在學證明中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("重試") { Task { await loadCertificate() } }
                        .buttonStyle(.borderedProminent)
                        .tint(.teal)
                }
                .padding()
            } else if let doc = pdfDocument {
                VStack(spacing: 0) {
                    Picker("語言", selection: $selectedLanguage) {
                        Text("中文").tag(CertificateLanguage.chinese)
                        Text("English").tag(CertificateLanguage.english)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    if isSwitching {
                        // 切換時只在 PDF 區域顯示小 loading
                        ProgressView("切換中...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        PDFKitView(document: doc)
                            .ignoresSafeArea(edges: .bottom)
                    }
                }
            }
        }
        .navigationTitle("在學證明")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if let doc = pdfDocument { sharePDF(doc) }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(pdfDocument == nil)
            }
        }
        .onChange(of: selectedLanguage) {
            Task { await loadCertificate() }
        }
        .task { await loadCertificate() }
    }
    
    // 載入在學證明 PDF
    func loadCertificate() async {
//        isLoading = true
//        errorMessage = nil
        
        // 第一次載入用 isLoading，之後用 isSwitching
        if pdfDocument == nil {
            isLoading = true
        } else {
            isSwitching = true
        }
        errorMessage = nil

        var request = URLRequest(url: selectedLanguage.url)
        request.httpMethod = "GET"
        request.httpShouldHandleCookies = false
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("https://stdsys.nkust.edu.tw", forHTTPHeaderField: "Referer")
        request.setValue("application/pdf", forHTTPHeaderField: "Accept")

        let cookieHeader = HTTPCookie.requestHeaderFields(with: cookies)
        cookieHeader.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        if let xsrf = cookies.first(where: { $0.name == "XSRF-TOKEN" }) {
            let decoded = xsrf.value.removingPercentEncoding ?? xsrf.value
            request.setValue(decoded, forHTTPHeaderField: "X-XSRF-TOKEN")
        }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let document = PDFDocument(data: data) else {
            errorMessage = "無法取得在學證明，請稍後再試"
            isLoading = false
            return
        }

        pdfDocument = document
        pdfData = data // 使用者下載
        isLoading = false
        isSwitching = false
    }
    
    // 下載在學證明
    func sharePDF(_ document: PDFDocument) {
        guard let data = pdfData else { return }
        
        // 暫存成檔案
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("在學證明.pdf")
        
        try? data.write(to: tempURL)
        
        let activityVC = UIActivityViewController(
            activityItems: [tempURL],
            applicationActivities: nil
        )
        
        // 找到目前的 UIViewController 來呈現
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

#Preview {
    SchoolSertifacate(cookies: [])
}
