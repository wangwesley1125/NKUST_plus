//
//  CourseView.swift
//  CollegeApp
//
//  Created by Wesley Wang on 2026/3/12.
//

import SwiftUI

struct CourseView: View {
    let cookies: [HTTPCookie]
    
    @State private var courses: [Course] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedDay = 0
    @State private var showEmptyPeriods = false
    
    let weekdays = ["週一","週二","週三","週四","週五","週六","週日"]
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("載入課表中...")
                } else if let error = errorMessage {
                    Text("錯誤：\(error)").foregroundColor(.red)
                } else {
                    VStack(spacing: 0) {
                        // 上方星期選擇列
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(0..<7, id: \.self) { index in
                                    Button {
                                        withAnimation { selectedDay = index }
                                    } label: {
                                        Text(weekdays[index])
                                            .font(.subheadline)
                                            .bold()
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(
                                                selectedDay == index
                                                ? Color.teal
                                                : Color(.systemGray5)
                                            )
                                            .foregroundColor(
                                                selectedDay == index ? .white : .primary
                                            )
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                        }
                        
                        Divider()
                        
                        // 左右滑動的課表
                        TabView(selection: $selectedDay) {
                            ForEach(0..<7, id: \.self) { dayIndex in
                                DayCourseView(
                                    dayName: weekdays[dayIndex],
                                    courses: courses.filter { $0.weekday == dayIndex },
                                    showEmptyPeriods: showEmptyPeriods
                                )
                                .tag(dayIndex)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                    }
                }
            }
            .navigationTitle("我的課表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation { showEmptyPeriods.toggle() }
                    } label: {
                        Label(
                            showEmptyPeriods ? "隱藏空堂" : "顯示空堂",
                            systemImage: showEmptyPeriods ? "eye.slash.fill" : "eye.fill"
                        )
                        .font(.caption)
                    }
                }
            }
        }
        .task { await loadCourses() }
    }
    
    func loadCourses() async {
        do {
            let html = try await CourseService.shared.fetchCourses(cookies: cookies)
            courses = try CourseParser.parse(html: html)
            // 預設跳到今天
            let weekday = Calendar.current.component(.weekday, from: Date())
            selectedDay = weekday == 1 ? 6 : weekday - 2 // 1=日,2=一...
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - 單天課表
struct DayCourseView: View {
    let dayName: String
    let courses: [Course]
    let showEmptyPeriods: Bool
    
    var body: some View {
        ScrollView {
            if courses.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.teal.opacity(0.5))
                    Text("今天沒有課！")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 250)
            } else {
                VStack(spacing: 12) {
                    // 依節次順序跑
                    ForEach(CourseParser.periods, id: \.self) { period in
                        if let course = courses.first(where: { $0.period == period }) {
                            // 有課 → 顯示卡片
                            CourseCard(course: course)
                        } else if showEmptyPeriods {
                            // 空堂 → 顯示淡色空堂格
                            EmptyPeriodCard(period: period)
                        }
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - 課程卡片
struct CourseCard: View {
    let course: Course
    
    var body: some View {
        HStack(spacing: 0) {
            // 左側時間條
            VStack(spacing: 2) {
                Text(course.period)
                    .font(.caption)
                    .bold()
                if let time = CourseParser.periodTimes[course.period] {
                    Text(time.0)
                        .font(.system(size: 10))
                    Text("|")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Text(time.1)
                        .font(.system(size: 10))
                }
            }
            .frame(width: 55)
            .padding(.vertical, 12)
            .background(Color.teal.opacity(0.15))
            
            // 右側課程資訊
            VStack(alignment: .leading, spacing: 4) {
                Text(course.name)
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    Label(course.teacher, systemImage: "person.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label(course.room, systemImage: "mappin.circle.fill")
                        .font(.caption)
                        .foregroundColor(.teal)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            
            Spacer()
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.07), radius: 5, x: 0, y: 2)
    }
}

struct EmptyPeriodCard: View {
    let period: String
    
    var body: some View {
        HStack(spacing: 0) {
            // 左側時間條
            VStack(spacing: 2) {
                Text(period)
                    .font(.caption)
                    .bold()
                if let time = CourseParser.periodTimes[period] {
                    Text(time.0).font(.system(size: 10))
                    Text("|").font(.system(size: 8)).foregroundColor(.secondary)
                    Text(time.1).font(.system(size: 10))
                }
            }
            .frame(width: 55)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            
            // 右側空堂提示
            Text("空堂")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.5))
                .padding(.horizontal, 14)
            
            Spacer()
        }
        .background(Color(.systemGray6).opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    CourseView(cookies: [])
}
