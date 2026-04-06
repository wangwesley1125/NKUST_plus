//
//  ShuttleBusView.swift
//  CollegeApp
//
//  Created by Wesley Wang on 2026/4/6.
//

import SwiftUI

// MARK: - Models

struct BusTrip: Identifiable {
    let id = UUID()
    let busId: Int
    let departureTime: String
    let reservedCount: Int
    let note: String
    let isReserved: Bool
    let reserveId: Int  // 0 = 未預約
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

// MARK: - HTML 解析器

struct TimetableParser {
    static func parse(html: String) -> [BusTrip] {
        var trips: [BusTrip] = []

        // 用 <tr> 切分每一列
        let rows = html.components(separatedBy: "<tr>").dropFirst(2) // 跳過 header

        for row in rows {
            guard row.contains("BusId") else { continue }

            let busId     = extractHiddenValue(id: "BusId",            in: row).flatMap { Int($0) } ?? 0
            let reserveId = extractHiddenValue(id: "ReserveId",        in: row).flatMap { Int($0) } ?? 0
            let stateCode = extractHiddenValue(id: "ReserveStateCode", in: row) ?? ""
            let isReserved = stateCode == "0" && reserveId != 0

            let time  = extractCellText(containing: ":", in: row) ?? "--:--"
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

    // 擷取 <input type="hidden" id="XXX" value="YYY" />
    private static func extractHiddenValue(id: String, in html: String) -> String? {
        let pattern = #"id="\#(id)"[^>]*value="([^"]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let r = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[r])
    }

    // 擷取時間欄（包含 ":" 的 td）
    private static func extractCellText(containing substring: String, in html: String) -> String? {
        let tdPattern = #"<td[^>]*>([\d:]+)</td>"#
        guard let regex = try? NSRegularExpression(pattern: tdPattern) else { return nil }
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        for match in matches {
            if let r = Range(match.range(at: 1), in: html) {
                let text = String(html[r])
                if text.contains(substring) { return text }
            }
        }
        return nil
    }

    // 擷取預約人數（時間後的第一個純數字 td）
    private static func extractCount(in html: String) -> Int? {
        let pattern = #"<td[^>]*>(\d+)</td>"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let r = Range(match.range(at: 1), in: html) else { return nil }
        return Int(String(html[r]))
    }

    // 班次說明（最後一個 td 的文字）
    private static func extractNote(in html: String) -> String? {
        let pattern = #"<td[^>]*>([^<]*)</td>\s*</tr>"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let r = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[r]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - 網路服務

class ShuttleBusService {
    static let shared = ShuttleBusService()
    private let baseURL = "https://vms.nkust.edu.tw"

    // 取得 CSRF Token
    func fetchToken(cookies: [HTTPCookie]) async throws -> String {
        var request = URLRequest(url: URL(string: "\(baseURL)/Bus/Bus")!)
        applyHeaders(to: &request, cookies: cookies)
        let (data, _) = try await URLSession.shared.data(for: request)
        let html = String(data: data, encoding: .utf8) ?? ""

        let pattern = #"name="__RequestVerificationToken"[^>]*value="([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let r = Range(match.range(at: 1), in: html) else {
            throw URLError(.cannotParseResponse)
        }
        return String(html[r])
    }

    // 取得班次列表
    func fetchTimetable(date: Date, route: BusRoute, token: String, cookies: [HTTPCookie]) async throws -> [BusTrip] {
        var request = URLRequest(url: URL(string: "\(baseURL)/Bus/Bus/GetTimetableGrid")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("\(baseURL)/Bus/Bus", forHTTPHeaderField: "Referer")
        applyHeaders(to: &request, cookies: cookies)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        let dateStr = formatter.string(from: date)

        let body = "driveDate=\(dateStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? dateStr)&beginStation=\(route.beginStation.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&endStation=\(route.endStation.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&__RequestVerificationToken=\(token)"
        request.httpBody = body.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        let html = String(data: data, encoding: .utf8) ?? ""
        return TimetableParser.parse(html: html)
    }

    // 預約
    func createReserve(busId: Int, token: String, cookies: [HTTPCookie]) async throws -> ReserveResponse {
        var request = URLRequest(url: URL(string: "\(baseURL)/Bus/Bus/CreateReserve")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("\(baseURL)/Bus/Bus", forHTTPHeaderField: "Referer")
        applyHeaders(to: &request, cookies: cookies)
        request.httpBody = "busId=\(busId)&__RequestVerificationToken=\(token)".data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(ReserveResponse.self, from: data)
    }

    // 取消預約
    func cancelReserve(reserveId: Int, token: String, cookies: [HTTPCookie]) async throws -> ReserveResponse {
        var request = URLRequest(url: URL(string: "\(baseURL)/Bus/Bus/CancelReserve")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("\(baseURL)/Bus/Bus", forHTTPHeaderField: "Referer")
        applyHeaders(to: &request, cookies: cookies)
        request.httpBody = "reserveId=\(reserveId)&__RequestVerificationToken=\(token)".data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(ReserveResponse.self, from: data)
    }

    // 確認登入狀態
    func checkExpire(cookies: [HTTPCookie]) async -> Bool {
        var request = URLRequest(url: URL(string: "\(baseURL)/Account/CheckExpire")!)
        applyHeaders(to: &request, cookies: cookies)
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let text = String(data: data, encoding: .utf8) else { return false }
        return text.trimmingCharacters(in: .whitespacesAndNewlines) == "alive"
    }

    private func applyHeaders(to request: inout URLRequest, cookies: [HTTPCookie]) {
        HTTPCookie.requestHeaderFields(with: cookies).forEach {
            request.setValue($0.value, forHTTPHeaderField: $0.key)
        }
        // XSRF Token（如果有）
        if let xsrf = cookies.first(where: { $0.name == "XSRF-TOKEN" }) {
            request.setValue(xsrf.value, forHTTPHeaderField: "X-XSRF-TOKEN")
        }
    }
}

// MARK: - 主畫面

struct ShuttleBusView: View {
    let cookies: [HTTPCookie]

    @State private var selectedRoute = busRoutes[0]
    @State private var selectedDate  = Date()
    @State private var trips: [BusTrip] = []
    @State private var token = ""
    @State private var isLoading = true
    @State private var isActionLoading = false
    @State private var errorMessage: String?
    @State private var toast: ToastMessage?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    tripList
                }
            }
            .navigationTitle("校車預約")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task { await initialLoad() }
            .overlay(alignment: .bottom) {
                if let toast = toast {
                    ToastView(message: toast)
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - 路線 + 日期選擇器

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                .labelsHidden()
                .onChange(of: selectedDate) { _, _ in
                    Task { await loadTimetable() }
                }
        }
    }

    // MARK: - 路線選擇 + 班次列表

    private var tripList: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 路線切換
                routePicker

                // 班次列表
                if trips.isEmpty {
                    emptyView
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(trips) { trip in
                            TripRowView(
                                trip: trip,
                                isActionLoading: isActionLoading
                            ) {
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

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bus")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("此日期無班次")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("載入中…").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    // MARK: - 邏輯

    func initialLoad() async {
        isLoading = true
        errorMessage = nil

        // 先確認登入狀態
        let alive = await ShuttleBusService.shared.checkExpire(cookies: cookies)
        guard alive else {
            errorMessage = "登入已過期，請重新登入"
            isLoading = false
            return
        }

        do {
            token = try await ShuttleBusService.shared.fetchToken(cookies: cookies)
            await loadTimetable()
        } catch {
            errorMessage = "無法連線至校車系統"
        }
        isLoading = false
    }

    func loadTimetable() async {
        isLoading = true
        do {
            trips = try await ShuttleBusService.shared.fetchTimetable(
                date: selectedDate,
                route: selectedRoute,
                token: token,
                cookies: cookies
            )
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
                    reserveId: trip.reserveId, token: token, cookies: cookies)
            } else {
                response = try await ShuttleBusService.shared.createReserve(
                    busId: trip.busId, token: token, cookies: cookies)
            }

            withAnimation(.spring(response: 0.35)) {
                toast = ToastMessage(
                    text: response.title,
                    isSuccess: response.success,
                    id: UUID()
                )
            }

            if response.success {
                await loadTimetable()
                // 重新取 token（伺服器可能更新）
                if let newToken = try? await ShuttleBusService.shared.fetchToken(cookies: cookies) {
                    token = newToken
                }
            }

            // Toast 自動消失
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
            // 狀態圖示
            ZStack {
                Circle()
                    .fill(trip.isReserved ? Color.teal.opacity(0.15) : Color(.systemGray5))
                    .frame(width: 44, height: 44)
                Image(systemName: trip.isReserved ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(trip.isReserved ? .teal : .secondary)
            }

            // 時間與說明
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

            // 預約人數
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(trip.reservedCount)")
                    .font(.title3.monospacedDigit().weight(.medium))
                    .foregroundStyle(trip.isReserved ? .teal : .primary)
                Text("已預約")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // 預約 / 取消按鈕
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