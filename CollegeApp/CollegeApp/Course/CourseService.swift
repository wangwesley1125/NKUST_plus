//
//  CourseService.swift
//  CollegeApp
//
//  Created by Wesley Wang on 2026/3/12.
//

import Foundation

struct CourseSemester: Identifiable, Equatable, Decodable {
    var id: String { value }
    let text: String
    let value: String

    enum CodingKeys: String, CodingKey {
        case text, value
    }
}

private struct SemesterResponse: Decodable {
    let result: [CourseSemester]
    let success: Bool
}

class CourseService {
    static let shared = CourseService()

    // MARK: - 從課表查詢頁面解析最新學期（不需要 studentId）
    private func fetchLatestSemester(cookies: [HTTPCookie]) async throws -> String {
        let url = URL(string: "https://stdsys.nkust.edu.tw/student/Course/StudentCourseQuery")!
        var request = URLRequest(url: url)
        HTTPCookie.requestHeaderFields(with: cookies).forEach {
            request.setValue($0.value, forHTTPHeaderField: $0.key)
        }
        let (data, _) = try await URLSession.shared.data(for: request)
        let html = String(data: data, encoding: .utf8) ?? ""

        let pattern = #"(?:value="|")(\d{3}-\d)(?:"|")"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let range = Range(match.range(at: 1), in: html) {
            return String(html[range])
        }

        let year = Calendar.current.component(.year, from: Date()) - 1911
        let month = Calendar.current.component(.month, from: Date())
        return month >= 8 ? "\(year)-1" : "\(year - 1)-2"
    }

    // MARK: - 從頁面解析 studentId
    func fetchStudentId(cookies: [HTTPCookie]) async throws -> String {
        let url = URL(string: "https://stdsys.nkust.edu.tw/student/Course/StudentCourseQuery")!
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("zh-TW,zh;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("https://stdsys.nkust.edu.tw", forHTTPHeaderField: "Referer")
        HTTPCookie.requestHeaderFields(with: cookies).forEach {
            request.setValue($0.value, forHTTPHeaderField: $0.key)
        }

        let (data, _) = try await URLSession.shared.data(for: request)
        let html = String(data: data, encoding: .utf8) ?? ""

        let patterns = [
            #"stdId=([A-Za-z]\d{8,9})"#,
            #"[Ss]td[Ii]d[\"']?\s*[=:]\s*[\"']?([A-Za-z]\d{8,9})"#,
            #"學號[：:]\s*([A-Za-z]\d{8,9})"#,
            #"([A-Za-z]\d{9})"#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                return String(html[range])
            }
        }
        throw URLError(.cannotParseResponse)
    }

    // MARK: - 抓完整學期清單
    func fetchSemesters(cookies: [HTTPCookie], studentId: String) async throws -> [CourseSemester] {
        let url = URL(string: "https://stdsys.nkust.edu.tw/student/WebCode/GetSchoolYearSmsCodes")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("https://stdsys.nkust.edu.tw", forHTTPHeaderField: "Origin")
        request.setValue("https://stdsys.nkust.edu.tw/student/Course/StudentCourseQuery", forHTTPHeaderField: "Referer")
        HTTPCookie.requestHeaderFields(with: cookies).forEach {
            request.setValue($0.value, forHTTPHeaderField: $0.key)
        }
        if let xsrf = cookies.first(where: { $0.name == "XSRF-TOKEN" }) {
            request.setValue(xsrf.value, forHTTPHeaderField: "X-XSRF-TOKEN")
        }
        request.httpBody = "stdId=\(studentId)".data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(SemesterResponse.self, from: data)
        guard decoded.success else { throw URLError(.badServerResponse) }
        return decoded.result
    }

    // MARK: - 抓課表 HTML
    func fetchCourses(cookies: [HTTPCookie], schoolYearSms: String = "") async throws -> String {
        let targetSemester = schoolYearSms.isEmpty
            ? try await fetchLatestSemester(cookies: cookies)
            : schoolYearSms

        let url = URL(string: "https://stdsys.nkust.edu.tw/student/Course/StudentCourseQuery/Query")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("https://stdsys.nkust.edu.tw", forHTTPHeaderField: "Origin")
        request.setValue("https://stdsys.nkust.edu.tw/student/Course/StudentCourseQuery", forHTTPHeaderField: "Referer")
        HTTPCookie.requestHeaderFields(with: cookies).forEach {
            request.setValue($0.value, forHTTPHeaderField: $0.key)
        }
        if let xsrf = cookies.first(where: { $0.name == "XSRF-TOKEN" }) {
            request.setValue(xsrf.value, forHTTPHeaderField: "X-XSRF-TOKEN")
        }
        request.httpBody = "schoolYearSms=\(targetSemester)".data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        let html = String(data: data, encoding: .utf8) ?? ""
        return html
    }
}
