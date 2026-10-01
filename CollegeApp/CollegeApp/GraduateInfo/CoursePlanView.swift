//
//  CoursePlanView.swift
//  CollegeApp
//
//  Created by Wesley on 2026/10/1.
//
//  課程結構規劃表（畢業修課狀況預覽的第二個分頁「課規課程修課狀況」）
//  網頁上是 HTML 表格，這裡用 WKWebView 顯示，保留原本的顏色並可縮放。

import SwiftUI
import WebKit

// MARK: - 課程規劃頁
struct CoursePlanView: View {
    let cookies: [HTTPCookie]

    @State private var html: String?
    @State private var errorMessage: String?

    private static let baseURL = URL(string: "https://stdsys.nkust.edu.tw/student/Graduation/StudyStatusPreview/")

    var body: some View {
        Group {
            if let html {
                HTMLWebView(html: html, baseURL: Self.baseURL)
                    .ignoresSafeArea(edges: .bottom)
            } else if let errorMessage {
                ContentUnavailableView(
                    "無法載入課程規劃",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView("載入中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("課程規劃")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard html == nil else { return }
            await load()
        }
    }

    private func load() async {
        do {
            let fragment = try await GraduationService.shared.fetchCourseStructure(cookies: cookies)
            html = Self.wrap(fragment)
        } catch GraduationError.sessionExpired {
            errorMessage = "登入已過期，請重新登入"
        } catch {
            print("課程規劃載入失敗：\(error)")
            errorMessage = "請稍後再試"
        }
    }

    /// 分頁內容只是一段 HTML 片段，包上完整的頁面與樣式
    private static func wrap(_ fragment: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="zh-tw">
        <head>
          <meta charset="utf-8">
          <!-- 用較寬的版面排版，進來時自動縮到符合螢幕，可再雙指放大 -->
          <meta name="viewport" content="width=1100">
          <link rel="stylesheet" href="/student/_content/Nkust.Web.Core/libs/bootstrap/dist/css/bootstrap.min.css">
          <style>
            :root { color-scheme: light; }
            body {
              margin: 0;
              padding: 16px;
              background: #ffffff;
              font-family: -apple-system, "PingFang TC", sans-serif;
            }
            table { border-collapse: collapse; width: 100%; }
            td, th {
              border: 1px solid #333;
              padding: 6px;
              vertical-align: middle;
              text-align: center;
            }
            /* 網頁上的「列印PDF」等按鈕在 App 裡用不到 */
            .btn, button { display: none !important; }

            /* ← 新增：解除學校頁面裡固定高度、內部捲動的容器，讓整張表展開 */
            html, body, div, section, article, fieldset, .card, .card-body,
            .k-content, .k-tabstrip-content, .table-responsive {
              height: auto !important;
              max-height: none !important;
              overflow: visible !important;
            }
          </style>
        </head>
        <body>
        \(fragment)
        </body>
        </html>
        """
    }
}

// MARK: - WKWebView 包裝
struct HTMLWebView: UIViewRepresentable {
    let html: String
    let baseURL: URL?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .white
        webView.scrollView.minimumZoomScale = 0.3
        webView.scrollView.maximumZoomScale = 4
        #if DEBUG
        webView.isInspectable = true   // ← 新增：可用 Mac 的 Safari 檢查 WebView
        #endif
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // 內容沒變就不要重新載入，避免縮放位置被重置
        guard context.coordinator.loadedHTML != html else { return }
        context.coordinator.loadedHTML = html
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    final class Coordinator {
        var loadedHTML: String?
    }
}

#Preview {
    NavigationStack {
        CoursePlanView(cookies: [])
    }
}
