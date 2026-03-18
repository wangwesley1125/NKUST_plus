//
//  MainView.swift
//  CollegeApp
//
//  Created by 王耀偉 on 2026/3/17.
//

import SwiftUI
import Combine

// MARK: - 課程狀態
enum CourseStatus {
    case ongoing    // 上課中
    case upcoming   // 即將上課（今日剩餘）
    case finished   // 已結束
    case future     // 尚未到達（非今日）
}

// MARK: - 課程狀態判斷
func courseStatus(for period: String) -> CourseStatus {
    guard let times = CourseParser.periodTimes[period] else { return .future }

    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    formatter.locale = Locale(identifier: "zh_TW")

    let nowStr = formatter.string(from: Date())
    guard
        let start = formatter.date(from: times.0),
        let end   = formatter.date(from: times.1),
        let now   = formatter.date(from: nowStr)
    else { return .future }

    if now >= start && now <= end { return .ongoing }
    if now < start { return .upcoming }
    return .finished
}

// MARK: - 課程進度計算（0.0 ~ 1.0）
private func courseProgress(for period: String) -> Double? {
    guard let times = CourseParser.periodTimes[period] else { return nil }
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    formatter.locale = Locale(identifier: "zh_TW")
    let nowStr = formatter.string(from: Date())
    guard
        let start   = formatter.date(from: times.0),
        let end     = formatter.date(from: times.1),
        let nowTime = formatter.date(from: nowStr)
    else { return nil }
    let total   = end.timeIntervalSince(start)
    let elapsed = nowTime.timeIntervalSince(start)
    guard total > 0 else { return nil }
    return max(0, min(1, elapsed / total))
}

// MARK: - 剩餘分鐘計算
private func remainingMinutes(for period: String) -> Int? {
    guard let times = CourseParser.periodTimes[period] else { return nil }
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    formatter.locale = Locale(identifier: "zh_TW")
    let nowStr = formatter.string(from: Date())
    guard
        let end     = formatter.date(from: times.1),
        let nowTime = formatter.date(from: nowStr)
    else { return nil }
    let remaining = end.timeIntervalSince(nowTime)
    return remaining > 0 ? Int(remaining / 60) : 0
}

// MARK: - 天氣資料模型
struct KaohsiungWeather {
    let temperature: Double
    let weatherCode: Int
    let windSpeed: Double

    var sfSymbol: String {
        switch weatherCode {
        case 0:            return "sun.max.fill"
        case 1, 2:         return "cloud.sun.fill"
        case 3:            return "cloud.fill"
        case 45, 48:       return "cloud.fog.fill"
        case 51, 53, 55:   return "cloud.drizzle.fill"
        case 61, 63, 65:   return "cloud.rain.fill"
        case 71, 73, 75:   return "cloud.snow.fill"
        case 80, 81, 82:   return "cloud.heavyrain.fill"
        case 95, 96, 99:   return "cloud.bolt.rain.fill"
        default:           return "cloud.fill"
        }
    }

    var description: String {
        switch weatherCode {
        case 0:            return "晴天"
        case 1, 2:         return "多雲時晴"
        case 3:            return "多雲"
        case 45, 48:       return "霧"
        case 51, 53, 55:   return "毛毛雨"
        case 61, 63, 65:   return "雨"
        case 71, 73, 75:   return "雪"
        case 80, 81, 82:   return "大雨"
        case 95, 96, 99:   return "雷陣雨"
        default:           return "未知"
        }
    }
}

// MARK: - 天氣卡片（高雄）
private struct WeatherCard: View {
    @State private var weather: KaohsiungWeather?
    @State private var isFetching = true

    var body: some View {
        HStack(spacing: 16) {
            if isFetching {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else if let w = weather {
                Image(systemName: w.sfSymbol)
                    .font(.system(size: 38))
                    .symbolRenderingMode(.multicolor)
                    .frame(width: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text("高雄市")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(w.description)
                        .font(.subheadline).bold()
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(w.temperature))°C")
                        .font(.title).bold()
                    Label(String(format: "%.1f km/h", w.windSpeed), systemImage: "wind")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Label("無法取得天氣資訊", systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
        .task { await fetchWeather() }
    }

    func fetchWeather() async {
        let urlStr = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=22.6273&longitude=120.3014"
            + "&current=temperature_2m,weather_code,wind_speed_10m"
            + "&timezone=Asia%2FTaipei"
        guard let url = URL(string: urlStr) else { isFetching = false; return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json    = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let current = json["current"] as? [String: Any],
               let temp    = current["temperature_2m"] as? Double,
               let code    = current["weather_code"] as? Int,
               let wind    = current["wind_speed_10m"] as? Double {
                weather = KaohsiungWeather(temperature: temp, weatherCode: code, windSpeed: wind)
            }
        } catch {
            print("天氣載入失敗：\(error)")
        }
        isFetching = false
    }
}

// MARK: - MainView
struct MainView: View {

    @Binding var isLoggedIn: Bool
    let cookies: [HTTPCookie]

    @State private var profile  = StudentProfile()
    @State private var courses: [Course] = []
    @State private var isLoading = true
    @State private var now = Date()

    // 今天是週幾（0=週一 … 6=週日）
    private var todayIndex: Int {
        let weekday = Calendar.current.component(.weekday, from: now)
        return max(0, min(6, weekday - 2))
    }

    // 今天的課（依節次排序）
    private var todayCourses: [Course] {
        courses
            .filter { $0.weekday == todayIndex }
            .sorted {
                let order = CourseParser.periods
                let i0 = order.firstIndex(of: $0.period) ?? 0
                let i1 = order.firstIndex(of: $1.period) ?? 0
                return i0 < i1
            }
    }

    // 正在進行的課
    private var ongoingCourse: Course? {
        todayCourses.first { courseStatus(for: $0.period) == .ongoing }
    }

    // 即將上課（今日剩餘未開始的課）
    private var upcomingCourses: [Course] {
        todayCourses.filter { courseStatus(for: $0.period) == .upcoming }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("載入中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {

                            // MARK: 天氣卡片
                            WeatherCard()

                            // MARK: 正在進行的課
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(
                                    title: "上課中",
                                    icon: "dot.radiowaves.left.and.right",
                                    color: .teal
                                )
                                if let course = ongoingCourse {
                                    OngoingCourseCard(course: course)
                                } else {
                                    EmptyStateCard(
                                        icon: "cup.and.saucer.fill",
                                        message: "目前沒有進行中的課程"
                                    )
                                }
                            }

                            Divider()

                            // MARK: 即將上課
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: "即將上課", icon: "clock.fill", color: .orange)

                                if upcomingCourses.isEmpty {
                                    EmptyStateCard(
                                        icon: "checkmark.seal.fill",
                                        message: "今天剩餘沒有課程了"
                                    )
                                } else {
                                    VStack(spacing: 10) {
                                        ForEach(upcomingCourses) { course in
                                            UpcomingCourseRow(course: course)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("首頁")
            .navigationBarTitleDisplayMode(.large)
        }
        // 每分鐘更新一次狀態（進度條 + 課程狀態）
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { date in
            now = date
        }
        .task { await loadAll() }
    }

    // MARK: - 載入資料
    func loadAll() async {
        async let profileHTML = ProfileService.shared.fetchProfile(cookies: cookies)
        async let coursesHTML = CourseService.shared.fetchCourses(cookies: cookies)

        do {
            let (pHTML, cHTML) = try await (profileHTML, coursesHTML)
            profile = try ProfileParser.parse(html: pHTML)
            courses = try CourseParser.parse(html: cHTML)
        } catch ProfileError.sessionExpired {
            CookieStorage.clear()
            isLoggedIn = false
        } catch {
            print("載入失敗：\(error)")
        }
        isLoading = false
    }
}

// MARK: - Section Header
private struct SectionHeader: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - 正在進行課程卡（大卡片）
private struct OngoingCourseCard: View {
    let course: Course

    private var progress: Double { courseProgress(for: course.period) ?? 0 }
    private var remaining: Int   { remainingMinutes(for: course.period) ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 頂部資訊
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label("上課中", systemImage: "dot.radiowaves.left.and.right")
                        .font(.caption).bold()
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.teal)
                        .clipShape(Capsule())

                    Text(course.name)
                        .font(.title2).bold()
                        .foregroundColor(.primary)
                        .padding(.top, 6)
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color.teal.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Text(course.period)
                        .font(.title3).bold()
                        .foregroundColor(.teal)
                }
            }
            .padding([.horizontal, .top])
            .padding(.bottom, 12)

            // 進度條
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.teal.opacity(0.12))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [Color.teal.opacity(0.7), Color.teal],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * progress, height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    if let times = CourseParser.periodTimes[course.period] {
                        Text(times.0)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("剩餘 \(remaining) 分鐘")
                        .font(.caption2).bold()
                        .foregroundColor(.teal)
                    Spacer()
                    if let times = CourseParser.periodTimes[course.period] {
                        Text(times.1)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)

            Divider()

            // 教師 / 教室 / 時間
            HStack(spacing: 0) {
                InfoCell(icon: "person.fill",       label: course.teacher, color: .secondary)
                Divider().frame(height: 32)
                InfoCell(icon: "mappin.circle.fill", label: course.room,   color: .teal)
                if let time = CourseParser.periodTimes[course.period] {
                    Divider().frame(height: 32)
                    InfoCell(icon: "clock", label: "\(time.0)–\(time.1)", color: .secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.teal, lineWidth: 2)
        )
        .shadow(color: .teal.opacity(0.15), radius: 10, x: 0, y: 4)
    }
}

// MARK: - 即將上課列（小列）
private struct UpcomingCourseRow: View {
    let course: Course

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text(course.period)
                    .font(.caption).bold()
                if let time = CourseParser.periodTimes[course.period] {
                    Text(time.0).font(.system(size: 10))
                    Text("|").font(.system(size: 8)).foregroundColor(.secondary)
                    Text(time.1).font(.system(size: 10))
                }
            }
            .frame(width: 55)
            .padding(.vertical, 12)
            .background(Color.orange.opacity(0.12))
            .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(course.name)
                    .font(.subheadline).bold()
                    .foregroundColor(.primary)
                HStack(spacing: 8) {
                    Label(course.teacher, systemImage: "person.fill")
                        .font(.caption).foregroundColor(.secondary)
                    Label(course.room, systemImage: "mappin.circle.fill")
                        .font(.caption).foregroundColor(.teal)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Spacer()
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

// MARK: - 空狀態卡片
private struct EmptyStateCard: View {
    let icon: String
    let message: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.secondary.opacity(0.5))
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Info Cell（橫排資訊格）
private struct InfoCell: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        Label(label, systemImage: icon)
            .font(.caption)
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
    }
}

#Preview {
    MainView(isLoggedIn: .constant(true), cookies: [])
}
