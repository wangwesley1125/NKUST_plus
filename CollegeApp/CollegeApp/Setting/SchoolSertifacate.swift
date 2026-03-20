//
//  SchoolSertifacate.swift
//  CollegeApp
//
//  Created by Wesley Wang on 2026/3/19.
//

import SwiftUI
import PDFKit

struct SchoolSertifacate: View {
    let cookies: [HTTPCookie]
    
    @State private var pdfDocument: PDFDocument?
    @State private var isLoading = true
    @State private var errorMessage: String?

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
                PDFKitView(document: doc)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .navigationTitle("在學證明")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadCertificate() }
    }

    func loadCertificate() async {
        isLoading = true
        errorMessage = nil

        let url = URL(string: "https://stdsys.nkust.edu.tw/student/Doc/Status/Download")!
        var request = URLRequest(url: url)
        
        // 帶入 Cookie（需要登入）
        let cookieHeader = HTTPCookie.requestHeaderFields(with: cookies)
        cookieHeader.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        
        if let xsrf = cookies.first(where: { $0.name == "XSRF-TOKEN" }) {
            request.setValue(xsrf.value, forHTTPHeaderField: "X-XSRF-TOKEN")
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
        isLoading = false
    }
}

#Preview {
    SchoolSertifacate(cookies: [])
}
