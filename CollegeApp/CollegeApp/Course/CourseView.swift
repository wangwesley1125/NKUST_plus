//
//  CourseView.swift
//  CollegeApp
//
//  Created by Wesley Wang on 2026/3/12.
//

import SwiftUI
import WidgetKit

struct CourseView: View {
    let cookies: [HTTPCookie]
    
    @State private var courses: [Course] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedDay = 0
    @State private var showEmptyPeriods = false
    @AppStorage("showGrid") private var showGrid = false
    
    // 新增：學期相關
    @State private var semesters: [CourseSemester] = []
    @State private var selectedSemester: CourseSemester? = nil
    
    let weekdays = ["週一","週二","週三","週四","週五","週六","週日"]
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("載入課表中...")
                } else if let error = errorMessage {
                    Text("錯誤：\(error)").foregroundColor(.red)
                } else {
                    if showGrid {
                        WeekGridView(courses: courses)
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
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 標題改成學期 Menu
                ToolbarItem(placement: .principal) {
                    if semesters.isEmpty {
                        Text("我的課表")
                            .font(.headline)
                    } else {
                        Menu {
                            ForEach(semesters) { sem in
                                Button {
                                    selectedSemester = sem
                                    Task { await loadCourses(semester: sem.value) }
                                } label: {
                                    if sem.id == selectedSemester?.id {
                                        Label(sem.text, systemImage: "checkmark")
                                    } else {
                                        Text(sem.text)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(selectedSemester?.text ?? "我的課表")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Image(systemName: "chevron.down")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                // 右側：顯示空堂（UI 不變）
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
                    .disabled(showGrid)
                }
                
                // 左側：格狀切換（UI 不變）
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        withAnimation { showGrid.toggle() }
                    } label: {
                        Image(systemName: showGrid ? "list.bullet" : "square.grid.3x3.fill")
                            .font(.caption)
                    }
                }
            }
        }
        .task { await initialLoad() }
    }
    
    // MARK: - 初始化：抓 studentId → 學期清單 → 課表
    func initialLoad() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedId = try await CourseService.shared.fetchStudentId(cookies: cookies)
            let fetchedSemesters = try await CourseService.shared.fetchSemesters(
                cookies: cookies,
                studentId: fetchedId
            )
            await MainActor.run {
                semesters = fetchedSemesters
                // 預設選第一個非暑修的學期（-1 或 -2）
                selectedSemester = fetchedSemesters.first(where: {
                    $0.value.hasSuffix("-1") || $0.value.hasSuffix("-2")
                }) ?? fetchedSemesters.first
            }
            await loadCourses(semester: selectedSemester?.value ?? "")
        } catch {
            print("學期載入失敗，使用 fallback：\(error)")
            await loadCourses(semester: "")
        }
    }
    
    // MARK: - 載入指定學期課表
    func loadCourses(semester: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        do {
            let html = try await CourseService.shared.fetchCourses(
                cookies: cookies,
                schoolYearSms: semester
            )
            let parsed = try CourseParser.parse(html: html)
            let codable = parsed.map {
                CourseCodable(name: $0.name, teacher: $0.teacher,
                              room: $0.room, period: $0.period, weekday: $0.weekday)
            }
            // 只有正規學期（非暑修）才更新 Widget
            let isRegularSemester = semester.hasSuffix("-1") || semester.hasSuffix("-2")
            let isLatestRegular = semester == semesters.first(where: {
                $0.value.hasSuffix("-1") || $0.value.hasSuffix("-2")
            })?.value

            if semester.isEmpty || (isRegularSemester && isLatestRegular) {
                CourseStorage.shared.save(courses: codable)
                WidgetCenter.shared.reloadAllTimelines()
                print("✅ 已存 \(codable.count) 堂課")
            }
            await MainActor.run {
                courses = parsed
                let weekday = Calendar.current.component(.weekday, from: Date())
                selectedDay = weekday == 1 ? 6 : weekday - 2
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
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

// MARK: - 備註管理
class NoteStore {
    static let shared = NoteStore()
    
    func save(note: String, for courseKey: String) {
        UserDefaults.standard.set(note, forKey: "note_\(courseKey)")
    }
    
    func load(for courseKey: String) -> String {
        UserDefaults.standard.string(forKey: "note_\(courseKey)") ?? ""
    }
}

// MARK: - 課程卡片
struct CourseCard: View {
    let course: Course
    @State private var note: String = ""
    @State private var showNoteSheet = false
    
    var courseKey: String { "\(course.name)_\(course.period)" }
    
    var body: some View {
        Button {
            showNoteSheet = true
        } label: {
            HStack(spacing: 0) {
                // 左側時間條（不變）
                VStack(spacing: 2) {
                    Text(course.period)
                        .font(.caption)
                        .bold()
                    if let time = CourseParser.periodTimes[course.period] {
                        Text(time.0).font(.system(size: 10))
                        Text("|").font(.system(size: 8)).foregroundColor(.secondary)
                        Text(time.1).font(.system(size: 10))
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
                    
                    // 備注預覽
                    if !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                
                Spacer()
                
                Image(systemName: note.isEmpty ? "note.text.badge.plus" : "note.text")
                    .font(.caption)
                    .foregroundColor(note.isEmpty ? .secondary.opacity(0.4) : .teal)
                    .padding(.trailing, 12)
            }
            .background(Color(.systemGray6).opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.07), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .onAppear {
            note = NoteStore.shared.load(for: courseKey)
        }
        .sheet(isPresented: $showNoteSheet) {
            NoteSheet(courseName: course.name, note: $note) {
                NoteStore.shared.save(note: note, for: courseKey)
            }
        }
    }
}

// MARK: - 備注欄
struct NoteSheet: View {
    let courseName: String
    @Binding var note: String
    let onSave: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(courseName)
                    .font(.headline)
                    .padding(.horizontal)
                
                TextEditor(text: $note)
                    .scrollContentBackground(.hidden)  // 隱藏預設背景
                    .padding(8)
                    .frame(maxHeight: 200)
                    .background(Color(.systemGray4))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top)
            .navigationTitle("備注")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("儲存") {
                        onSave()
                        dismiss()
                    }
                    .bold()
                    .tint(.teal)
                }
            }
        }
        .presentationDetents([.height(300)])
    }
}

// MARK: - 空堂卡片
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
