//
//  MainView.swift
//  CollegeApp
//
//  Created by Wesley Wang on 2026/3/17.
//

import SwiftUI
import Combine
import StoreKit
import WidgetKit

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
        return weekday == 1 ? 6 : weekday - 2
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
    
    // 紀錄使用者是否在廣告的地方按過叉叉
    @State private var showInstagramBanner = !UserDefaults.standard.bool(forKey: "dismissedInstagramBanner")
    
    // 學分 state
    @State private var graduation: GraduationStatus?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("載入中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        
                        VStack(alignment: .leading, spacing: 24) {
                            
                            // MARK: Instagram Banner
                            if showInstagramBanner {
                                HStack(spacing: 12) {
                                    Image("instagram-logo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 36, height: 36)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("歡迎追蹤我們的 Instagram！")
                                            .font(.subheadline.weight(.semibold))
                                        Text("隨時掌握新功能與最新消息 🎉")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Link(destination: URL(string: "https://www.instagram.com/nkust_plus?igsh=MXR0NXR3MmJiczAybg%3D%3D&utm_source=qr")!) {
                                        Text("追蹤")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.pink)
                                            .clipShape(Capsule())
                                    }
                                    
                                    Button {
                                        withAnimation(.spring(response: 0.3)) {
                                            showInstagramBanner = false
                                        }
                                        UserDefaults.standard.set(true, forKey: "dismissedInstagramBanner")
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(12)
                                .background(Color.pink.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(Color.pink.opacity(0.2), lineWidth: 1)
                                )
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }

                            // MARK: 畢業學分卡片
                            if let graduation {
                                CreditCard(status: graduation, cookies: cookies)
                            }

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
                                        message: "目前沒有正在進行中的課程"
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
                                        message: "沒有課程了喔～🎉"
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
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("NKUST Plus")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        SettingView(isLoggedIn: $isLoggedIn, cookies: cookies)
                    } label: {
                        Image(systemName: "person.circle.fill")
                            .font(.title3)
                            .foregroundColor(.teal)
                    }
                }
            }
        }
        // 每分鐘更新一次狀態（進度條 + 課程狀態）
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { date in
            now = date
        }
        .task { await loadAll() }
        .onAppear {
            let launchCount = UserDefaults.standard.integer(forKey: "launchCount") + 1
            UserDefaults.standard.set(launchCount, forKey: "launchCount")
            
            if launchCount == 2 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    if let scene = UIApplication.shared.connectedScenes
                        .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                        SKStoreReviewController.requestReview(in: scene)
                    }
                }
            }
        }
    }

    // MARK: - 載入資料
    func loadAll() async {
        async let profileHTML = ProfileService.shared.fetchProfile(cookies: cookies)
        async let coursesHTML = CourseService.shared.fetchCourses(cookies: cookies)
        async let gradHTML    = GraduationService.shared.fetchStudyStatus(cookies: cookies)

        do {
            let (pHTML, cHTML) = try await (profileHTML, coursesHTML)
            profile = try ProfileParser.parse(html: pHTML)
            courses = try CourseParser.parse(html: cHTML)

            // 用同一份課表更新 Widget（原本在 LoginView 登入後另外抓一次，已移到這裡）
            updateWidget(with: courses)
        } catch ProfileError.sessionExpired {
            CookieStorage.clear()
            isLoggedIn = false
        } catch {
            print("載入失敗：\(error)")
        }

        do {
            graduation = try GraduationParser.parse(html: try await gradHTML)
        } catch {
            print("學分載入失敗：\(error)")
        }

        isLoading = false
    }

    // MARK: - 更新課表 Widget
    private func updateWidget(with courses: [Course]) {
        let codable = courses.map {
            CourseCodable(name: $0.name, teacher: $0.teacher,
                          room: $0.room, period: $0.period, weekday: $0.weekday)
        }
        CourseStorage.shared.save(courses: codable)
        WidgetCenter.shared.reloadAllTimelines()
        print("已更新 Widget，共 \(codable.count) 堂課")
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
