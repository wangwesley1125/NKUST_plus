//
//  ShuttleBusView.swift
//  CollegeApp
//
//  Created by Wesley Wang on 2026/4/6.
//

import SwiftUI
import WebKit

// MARK: - Models

struct BusTrip: Identifiable {
    let id = UUID()
    let busId: Int
    let departureTime: String
    let reservedCount: Int
    let note: String
    let isReserved: Bool
    let reserveId: Int
}

struct ReserveResponse: Decodable {
    let success: Bool
    let title: String
    let text: String
}

// MARK: - 路線定義

struct BusRoute: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let beginStation: String
    let endStation: String
}

let busRoutes: [BusRoute] = [
    BusRoute(label: "建工 ➜ 燕巢", beginStation: "建工", endStation: "燕巢"),
    BusRoute(label: "燕巢 ➜ 建工", beginStation: "燕巢", endStation: "建工"),
    BusRoute(label: "建工 ➜ 第一", beginStation: "建工", endStation: "第一"),
    BusRoute(label: "第一 ➜ 建工", beginStation: "第一", endStation: "建工"),
]

// MARK: - VMS Cookie 儲存

struct VMSCookieStorage {
    static let key = "vmsSavedCookies"

    static func save(_ cookies: [HTTPCookie]) {
        let data = cookies.compactMap { cookie -> [String: Any]? in
            cookie.properties?.reduce(into: [String: Any]()) { result, pair in
                result[pair.key.rawValue] = pair.value
            }
        }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() -> [HTTPCookie] {
        guard let data = UserDefaults.standard.array(forKey: key) as? [[String: Any]] else { return [] }
        return data.compactMap { dict in
            let properties = dict.reduce(into: [HTTPCookiePropertyKey: Any]()) { result, pair in
                result[HTTPCookiePropertyKey(pair.key)] = pair.value
            }
            return HTTPCookie(properties: properties)
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - HTML 解析器

struct TimetableParser {
    static func parse(html: String) -> [BusTrip] {
        var trips: [BusTrip] = []
        let rows = html.components(separatedBy: "<tr>").dropFirst(2)

        for row in rows {
            guard row.contains("BusId") else { continue }

            let busId     = extractHiddenValue(id: "BusId",            in: row).flatMap { Int($0) } ?? 0
            let reserveId = extractHiddenValue(id: "ReserveId",        in: row).flatMap { Int($0) } ?? 0
            let stateCode = extractHiddenValue(id: "ReserveStateCode", in: row) ?? ""
            let isReserved = stateCode == "0" && reserveId != 0

            let time  = extractTimeCell(in: row) ?? "--:--"
            let count = extractCount(in: row) ?? 0
            let note  = extractNote(in: row) ?? ""

            trips.append(BusTrip(
                busId: busId,
                departureTime: time,
                reservedCount: count,
                note: note,
                isReserved: isReserved,
                reserveId: reserveId
            ))
        }
        return trips
    }

    private static func extractHiddenValue(id: String, in html: String) -> String? {
        let pattern = "id=\"\(id)\"[^>]*value=\"([^\"]*)\""
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let r = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[r])
    }

    private static func extractTimeCell(in html: String) -> String? {
        let pattern = #"<td[^>]*>([\d]{2}:[\d]{2})</td>"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let r = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[r])
    }

    private static func extractCount(in html: String) -> Int? {
        let pattern = #"<td[^>]*>(\d+)</td>"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let r = Range(match.range(at: 1), in: html) else { return nil }
        return Int(String(html[r]))
    }

    private static func extractNote(in html: String) -> String? {
        let pattern = #"<td[^>]*>([^<]*)</td>\s*</tr>"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let r = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[r]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - 信任 nkust.edu.tw SSL 的 URLSession delegate

private class NKUSTSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.host.hasSuffix("nkust.edu.tw"),
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

// MARK: - 網路服務

class ShuttleBusService {
    static let shared = ShuttleBusService()
    private let baseURL = "https://vms.nkust.edu.tw"

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        return URLSession(configuration: config, delegate: NKUSTSessionDelegate(), delegateQueue: nil)
    }()

    // MARK: 確認登入狀態
    func checkExpire(cookies: [HTTPCookie]) async -> Bool {
        var request = URLRequest(url: URL(string: "\(baseURL)/Account/CheckExpire")!)
        applyHeaders(to: &request, cookies: cookies)
        guard let (data, _) = try? await session.data(for: request),
              let text = String(data: data, encoding: .utf8) else { return false }
        return text.trimmingCharacters(in: .whitespacesAndNewlines) == "alive"
    }

    // MARK: 自動登入（用 Keychain 帳密，vms 無 CAPTCHA）
    func autoLogin(username: String, password: String) async -> [HTTPCookie]? {
        guard let token = await fetchLoginPageToken() else { return nil }

        var request = URLRequest(url: URL(string: "\(baseURL)/")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(baseURL, forHTTPHeaderField: "Referer")
        request.httpShouldHandleCookies = false

        let encodedUser  = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? username
        let encodedPass  = password.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? password
        let encodedToken = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? token
        request.httpBody = "Account=\(encodedUser)&Password=\(encodedPass)&__RequestVerificationToken=\(encodedToken)&RememberMe=false".data(using: .utf8)

        guard let (_, response) = try? await session.data(for: request),
              let httpResponse = response as? HTTPURLResponse else { return nil }

        let headers = httpResponse.allHeaderFields as? [String: String] ?? [:]
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: URL(string: baseURL)!)

        let alive = await checkExpire(cookies: cookies)
        return alive ? cookies : nil
    }

    private func fetchLoginPageToken() async -> String? {
        guard let (data, _) = try? await session.data(from: URL(string: "\(baseURL)/")!),
              let html = String(data: data, encoding: .utf8) else { return nil }
        return extractToken(from: html)
    }

    // MARK: 取得班次頁 Token
    func fetchBusToken(cookies: [HTTPCookie]) async throws -> String {
        var request = URLRequest(url: URL(string: "\(baseURL)/Bus/Bus/Timetable")!)
        applyHeaders(to: &request, cookies: cookies)
        let (data, _) = try await session.data(for: request)
        let html = String(data: data, encoding: .utf8) ?? ""
        guard let token = extractToken(from: html) else { throw URLError(.cannotParseResponse) }
        return token
    }

    // MARK: 取得班次列表
    func fetchTimetable(date: Date, route: BusRoute, token: String, cookies: [HTTPCookie]) async throws -> [BusTrip] {
        var request = URLRequest(url: URL(string: "\(baseURL)/Bus/Bus/GetTimetableGrid")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("\(baseURL)/Bus/Bus/Timetable", forHTTPHeaderField: "Referer")
        applyHeaders(to: &request, cookies: cookies)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        let dateStr = formatter.string(from: date)
        let encodedDate  = dateStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? dateStr
        let encodedBegin = route.beginStation.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedEnd   = route.endStation.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        request.httpBody = "driveDate=\(encodedDate)&beginStation=\(encodedBegin)&endStation=\(encodedEnd)&__RequestVerificationToken=\(token)".data(using: .utf8)

        let (data, _) = try await session.data(for: request)
        let html = String(data: data, encoding: .utf8) ?? ""
        return TimetableParser.parse(html: html)
    }

    // MARK: 預約
    func createReserve(busId: Int, token: String, cookies: [HTTPCookie]) async throws -> ReserveResponse {
        var request = URLRequest(url: URL(string: "\(baseURL)/Bus/Bus/CreateReserve")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("\(baseURL)/Bus/Bus/Timetable", forHTTPHeaderField: "Referer")
        applyHeaders(to: &request, cookies: cookies)
        request.httpBody = "busId=\(busId)&__RequestVerificationToken=\(token)".data(using: .utf8)
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(ReserveResponse.self, from: data)
    }

    // MARK: 取消預約
    func cancelReserve(reserveId: Int, token: String, cookies: [HTTPCookie]) async throws -> ReserveResponse {
        var request = URLRequest(url: URL(string: "\(baseURL)/Bus/Bus/CancelReserve")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("\(baseURL)/Bus/Bus/Timetable", forHTTPHeaderField: "Referer")
        applyHeaders(to: &request, cookies: cookies)
        request.httpBody = "reserveId=\(reserveId)&__RequestVerificationToken=\(token)".data(using: .utf8)
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(ReserveResponse.self, from: data)
    }

    private func extractToken(from html: String) -> String? {
        let pattern = #"name="__RequestVerificationToken"[^>]*value="([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let r = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[r])
    }

    private func applyHeaders(to request: inout URLRequest, cookies: [HTTPCookie]) {
        HTTPCookie.requestHeaderFields(with: cookies).forEach {
            request.setValue($0.value, forHTTPHeaderField: $0.key)
        }
    }
}

// MARK: - VMS WKWebView 登入（fallback）

struct VMSLoginWebView: UIViewRepresentable {
    @Binding var vmsCookies: [HTTPCookie]
    @Binding var isLoggedIn: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: URL(string: "https://vms.nkust.edu.tw/")!))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: VMSLoginWebView
        init(_ parent: VMSLoginWebView) { self.parent = parent }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let url = webView.url?.absoluteString,
                  url.contains("vms.nkust.edu.tw/Home/Index") else { return }

            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                let vmsCookies = cookies.filter { $0.domain.contains("vms.nkust.edu.tw") }
                guard !vmsCookies.isEmpty else { return }
                DispatchQueue.main.async {
                    self.parent.vmsCookies = vmsCookies
                    VMSCookieStorage.save(vmsCookies)
                    self.parent.isLoggedIn = true
                }
            }
        }

        func webView(_ webView: WKWebView,
                     didReceive challenge: URLAuthenticationChallenge,
                     completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            if challenge.protectionSpace.host.hasSuffix("nkust.edu.tw"),
               let trust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: trust))
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        }
    }
}

// MARK: - VMS 登入畫面

struct VMSLoginView: View {
    @Binding var vmsCookies: [HTTPCookie]
    @Binding var isLoggedIn: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.teal)
                Text("車輛管理系統需要獨立登入")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground))

            VMSLoginWebView(vmsCookies: $vmsCookies, isLoggedIn: $isLoggedIn)
        }
        .navigationTitle("登入校車系統")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 主畫面

struct ShuttleBusView: View {
    let cookies: [HTTPCookie]

    @State private var vmsCookies: [HTTPCookie] = VMSCookieStorage.load()
    @State private var isVmsLoggedIn = false
    @State private var isCheckingLogin = true
    @State private var showManualLogin = false

    @State private var selectedRoute = busRoutes[0]
    @State private var selectedDate  = Date()
    @State private var trips: [BusTrip] = []
    @State private var token = ""
    @State private var isLoading = false
    @State private var isActionLoading = false
    @State private var errorMessage: String?
    @State private var toast: ToastMessage?

    var body: some View {
        NavigationStack {
            Group {
                if isCheckingLogin {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("驗證登入狀態…").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                } else if !isVmsLoggedIn {
                    needsLoginView

                } else if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("載入班次中…").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                } else if let error = errorMessage {
                    errorView(error)

                } else {
                    tripListView
                }
            }
            .navigationTitle("校車預約")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isVmsLoggedIn && !isCheckingLogin {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        DatePicker("", selection: $selectedDate, displayedComponents: .date)
                            .labelsHidden()
                            .onChange(of: selectedDate) { _, _ in
                                Task { await loadTimetable() }
                            }
                    }
                }
            }
            .task { await checkAndLogin() }
            .onChange(of: isVmsLoggedIn) { _, loggedIn in
                if loggedIn { Task { await initialLoad() } }
            }
            .overlay(alignment: .bottom) {
                if let toast = toast {
                    ToastView(message: toast)
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - 未登入畫面

    private var needsLoginView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bus.fill")
                .font(.system(size: 48))
                .foregroundStyle(.teal)
            Text("需要登入車輛管理系統")
                .font(.headline)
            Text("校車預約使用獨立的登入系統，請點下方按鈕登入。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("前往登入") { showManualLogin = true }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationDestination(isPresented: $showManualLogin) {
            VMSLoginView(vmsCookies: $vmsCookies, isLoggedIn: $isVmsLoggedIn)
        }
    }

    // MARK: - 班次畫面

    private var tripListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                routePicker
                if trips.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bus")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("此日期無班次")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(trips) { trip in
                            TripRowView(trip: trip, isActionLoading: isActionLoading) {
                                Task { await handleTap(trip: trip) }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top, 8)
        }
    }

    private var routePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(busRoutes) { route in
                    Button {
                        selectedRoute = route
                        Task { await loadTimetable() }
                    } label: {
                        Text(route.label)
                            .font(.subheadline.weight(selectedRoute.id == route.id ? .semibold : .regular))
                            .foregroundStyle(selectedRoute.id == route.id ? .white : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedRoute.id == route.id ? Color.teal : Color(.systemGray5))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("重試") { Task { await initialLoad() } }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 登入邏輯

    func checkAndLogin() async {
        isCheckingLogin = true

        if !vmsCookies.isEmpty {
            let alive = await ShuttleBusService.shared.checkExpire(cookies: vmsCookies)
            if alive {
                isVmsLoggedIn = true
                isCheckingLogin = false
                await initialLoad()
                return
            }
        }

        if let cred = CredentialStorage.load(),
           let newCookies = await ShuttleBusService.shared.autoLogin(
               username: cred.username, password: cred.password) {
            vmsCookies = newCookies
            VMSCookieStorage.save(newCookies)
            isVmsLoggedIn = true
            isCheckingLogin = false
            await initialLoad()
            return
        }

        isVmsLoggedIn = false
        isCheckingLogin = false
    }

    func initialLoad() async {
        isLoading = true
        errorMessage = nil
        do {
            token = try await ShuttleBusService.shared.fetchBusToken(cookies: vmsCookies)
            await loadTimetable()
        } catch {
            errorMessage = "無法連線至校車系統，請稍後再試"
        }
        isLoading = false
    }

    func loadTimetable() async {
        isLoading = true
        do {
            trips = try await ShuttleBusService.shared.fetchTimetable(
                date: selectedDate, route: selectedRoute, token: token, cookies: vmsCookies)
        } catch {
            errorMessage = "無法取得班次資料"
        }
        isLoading = false
    }

    func handleTap(trip: BusTrip) async {
        guard !isActionLoading else { return }
        isActionLoading = true
        defer { isActionLoading = false }

        do {
            let response: ReserveResponse
            if trip.isReserved {
                response = try await ShuttleBusService.shared.cancelReserve(
                    reserveId: trip.reserveId, token: token, cookies: vmsCookies)
            } else {
                response = try await ShuttleBusService.shared.createReserve(
                    busId: trip.busId, token: token, cookies: vmsCookies)
            }

            withAnimation(.spring(response: 0.35)) {
                toast = ToastMessage(text: response.title, isSuccess: response.success, id: UUID())
            }

            if response.success {
                await loadTimetable()
                if let newToken = try? await ShuttleBusService.shared.fetchBusToken(cookies: vmsCookies) {
                    token = newToken
                }
            }

            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { toast = nil }

        } catch {
            withAnimation {
                toast = ToastMessage(text: "操作失敗，請稍後再試", isSuccess: false, id: UUID())
            }
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { toast = nil }
        }
    }
}

// MARK: - 班次列

struct TripRowView: View {
    let trip: BusTrip
    let isActionLoading: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(trip.isReserved ? Color.teal.opacity(0.15) : Color(.systemGray5))
                    .frame(width: 44, height: 44)
                Image(systemName: trip.isReserved ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(trip.isReserved ? .teal : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(trip.departureTime)
                    .font(.title3.monospacedDigit().weight(.semibold))
                if !trip.note.isEmpty {
                    Text(trip.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(trip.reservedCount)")
                    .font(.title3.monospacedDigit().weight(.medium))
                    .foregroundStyle(trip.isReserved ? .teal : .primary)
                Text("已預約")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Button(action: onTap) {
                Text(trip.isReserved ? "取消" : "預約")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(trip.isReserved ? .red : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(trip.isReserved ? Color.red.opacity(0.1) : Color.teal)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isActionLoading)
            .opacity(isActionLoading ? 0.5 : 1)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Toast

struct ToastMessage: Identifiable {
    let text: String
    let isSuccess: Bool
    let id: UUID
}

struct ToastView: View {
    let message: ToastMessage

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: message.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(message.isSuccess ? .green : .red)
            Text(message.text)
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

#Preview {
    ShuttleBusView(cookies: [])
}
