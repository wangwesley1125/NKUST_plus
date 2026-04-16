//
//  CourseService.swift
//  CollegeApp
//
//  Created by Wesley Wang on 2026/3/12.
//

import Foundation

class CourseService {
    static let shared = CourseService()
    
    func fetchCourses(cookies: [HTTPCookie], schoolYearSms: String = "114-2") async throws -> String {
        let url = URL(string: "https://stdsys.nkust.edu.tw/student/Course/StudentCourseQuery/Query")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("https://stdsys.nkust.edu.tw", forHTTPHeaderField: "Origin")
        request.setValue("https://stdsys.nkust.edu.tw/student/Course/StudentCourseQuery", forHTTPHeaderField: "Referer")
        
        // 注入所有 Cookie
        let cookieHeader = HTTPCookie.requestHeaderFields(with: cookies)
        cookieHeader.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        
        // XSRF Token 單獨帶入 Header
        if let xsrf = cookies.first(where: { $0.name == "XSRF-TOKEN" }) {
            request.setValue(xsrf.value, forHTTPHeaderField: "X-XSRF-TOKEN")
        }
        
        // POST Body
        request.httpBody = "schoolYearSms=\(schoolYearSms)".data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Debug：確認 HTTP 狀態碼
        if let httpResponse = response as? HTTPURLResponse {
            print("Status Code: \(httpResponse.statusCode)")
        }
        
        let html = String(data: data, encoding: .utf8) ?? ""
        print("HTML 長度：\(html.count) 字元")
        print(html.prefix(300)) // 印出前 300 字確認內容
        return html
    }
}
