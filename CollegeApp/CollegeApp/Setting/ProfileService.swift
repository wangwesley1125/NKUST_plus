//
//  ProfileService.swift
//  CollegeApp
//
//  Created by Wesley Wang on 2026/3/17.
//

import Foundation

enum ProfileError: Error {
    case sessionExpired
}

class ProfileService {
    static let shared = ProfileService()
    
    // 不跟隨 redirect 的 delegate
    private class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest,
            completionHandler: @escaping (URLRequest?) -> Void
        ) {
            completionHandler(nil) // 不跟隨，讓我們拿到 302
        }
    }
    
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        return URLSession(configuration: config, delegate: NoRedirectDelegate(), delegateQueue: nil)
    }()
    
    func fetchProfile(cookies: [HTTPCookie]) async throws -> String {
        let url = URL(string: "https://stdsys.nkust.edu.tw/student/Register/StudentDataQuery")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let cookieHeader = HTTPCookie.requestHeaderFields(with: cookies)
        cookieHeader.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        
        let (data, response) = try await session.data(for: request)
        
        // 302 跳去 Login 代表 Session 已過期
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 302,
           let location = httpResponse.value(forHTTPHeaderField: "Location"),
           location.contains("Login") {
            throw ProfileError.sessionExpired
        }
        
        return String(data: data, encoding: .utf8) ?? ""
    }
}
