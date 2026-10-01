//
//  GraduationService.swift
//  CollegeApp
//
//  Created by Wesley on 2026/10/1.
//
//  抓取「畢業修課狀況預覽」頁面 HTML（三個分頁都在同一份 HTML 裡，只需抓一次）
//  主頁面 StudyStatusPreview 只有「說明」，另外兩個分頁是 Kendo TabStrip 用 AJAX 載入：
//    - 課規課程修課狀況：/StudyStatusPreview/CourseStructureView
//    - 課規課程修課學分狀況：/StudyStatusPreview/HierarchyStudyCheckView
//

import Foundation

final class GraduationService {

    static let shared = GraduationService()
    private init() {}

    private let baseURL = "https://stdsys.nkust.edu.tw/student/Graduation/StudyStatusPreview"

    /// 課規課程修課學分狀況（第三個分頁）
    func fetchStudyStatus(cookies: [HTTPCookie]) async throws -> String {
        try await fetch(path: "/HierarchyStudyCheckView", cookies: cookies)
    }

    /// 課規課程修課狀況（第二個分頁，課程結構表格，之後要用再呼叫）
    func fetchCourseStructure(cookies: [HTTPCookie]) async throws -> String {
        try await fetch(path: "/CourseStructureView", cookies: cookies)
    }

    // MARK: - 共用
    private func fetch(path: String, cookies: [HTTPCookie]) async throws -> String {
        guard let url = URL(string: baseURL + path) else {
            throw GraduationError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.allHTTPHeaderFields = HTTPCookie.requestHeaderFields(with: cookies)
        // 模擬 Kendo / jQuery 的 AJAX 請求
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue(baseURL, forHTTPHeaderField: "Referer")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw GraduationError.invalidResponse
        }

        // 登入過期：401/403，或被導回登入頁
        if http.statusCode == 401 || http.statusCode == 403 {
            throw GraduationError.sessionExpired
        }
        if let finalURL = http.url?.absoluteString.lowercased(),
           finalURL.contains("login") {
            throw GraduationError.sessionExpired
        }
        guard (200..<300).contains(http.statusCode) else {
            throw GraduationError.invalidResponse
        }

        let html = String(decoding: data, as: UTF8.self)

        // 拿到的是登入頁而不是資料
        if html.contains("Account/Login") && !html.contains("課規") {
            throw GraduationError.sessionExpired
        }

        return html
    }
}
