//
//  SafariSheet.swift
//  CollegeApp
//
//  在 App 內以 Sheet 開啟網頁（SFSafariViewController），不跳到 Safari。
//  支援 iOS 密碼自動填入（iCloud 鑰匙圈）、網址列、分享等 Safari 功能。
//
//  使用方式：在任何 View 後面加上 `.openLinksInSafariSheet()`，
//  該 View 裡所有的 `Link` 就會自動改成在 Sheet 中開啟。
//

import SwiftUI
import SafariServices

// MARK: - SFSafariViewController 包裝
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.barCollapsingEnabled = true       // 往下捲時收起網址列
        config.entersReaderIfAvailable = false

        let safari = SFSafariViewController(url: url, configuration: config)
        safari.preferredControlTintColor = .systemTeal   // 按鈕顏色跟 App 一致
        safari.dismissButtonStyle = .close               // 左上角顯示「關閉」
        safari.delegate = context.coordinator
        return safari
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}

    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        // 使用者按「關閉」→ 收起 Sheet
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            dismiss()
        }
    }
}

// MARK: - 讓 Link 改用 Sheet 開啟
struct WebLink: Identifiable {
    let id = UUID()
    let url: URL
}

private struct SafariSheetModifier: ViewModifier {
    @State private var link: WebLink?

    func body(content: Content) -> some View {
        content
            // 攔截這個 View 裡所有 Link / openURL
            .environment(\.openURL, OpenURLAction { url in
                // 只有 http / https 用 Sheet 開；mailto 等交給系統
                guard let scheme = url.scheme?.lowercased(),
                      scheme == "http" || scheme == "https" else {
                    return .systemAction
                }

                // 有專屬 App 的網站交給系統（會直接開 Instagram / App Store App）
                let host = url.host?.lowercased() ?? ""
                if host.hasSuffix("instagram.com") || host == "apps.apple.com" {
                    return .systemAction
                }

                link = WebLink(url: url)
                return .handled
            })
            .sheet(item: $link) { link in
                SafariView(url: link.url)
                    .ignoresSafeArea()
            }
    }
}

extension View {
    /// 讓這個 View 裡所有的 `Link` 都在 App 內以 Sheet 開啟
    func openLinksInSafariSheet() -> some View {
        modifier(SafariSheetModifier())
    }
}
