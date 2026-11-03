//
//  CourseRecommendView.swift
//  CollegeApp
//
//  課程推薦頁（從 MainView 左上角進入）
//  - 最上方：搜尋框（查課名）
//  - 下方：科系膠囊（全部 / 本系 / 其他有人評過的科系，後端有新科系就自動多一顆）
//  - 列表：同課名的課集中在一起，底下列出各老師的推薦與心得數
//  - 點一門課：看該科系（或全校）同學的修課心得，可檢舉、封鎖
//

import SwiftUI

struct CourseRecommendView: View {
    @State private var departments: [DepartmentInfo] = []
    /// 空字串 = 全部（全校）
    @State private var selectedDepartment = ""
    @State private var searchText = ""
    @State private var courses: [BrowseCourse] = []
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var detail: BrowseCourse?
    @FocusState private var isSearchFocused: Bool

    private var store: CourseRatingStore { .shared }

    /// 膠囊順序：全部 → 本系 → 其他科系（依評分數多到少）
    private var capsuleDepartments: [String] {
        var list = [""]
        let mine = store.departmentName
        if !mine.isEmpty { list.append(mine) }
        list += departments.map(\.department).filter { $0 != mine }
        return list
    }

    /// 同課名集中：依第一次出現的順序分組（後端已依推薦人數排序）
    private var groupedCourses: [(name: String, items: [BrowseCourse])] {
        var order: [String] = []
        var groups: [String: [BrowseCourse]] = [:]
        for course in courses {
            if groups[course.name] == nil { order.append(course.name) }
            groups[course.name, default: []].append(course)
        }
        return order.map { ($0, groups[$0] ?? []) }
    }

    /// 搜尋字或科系改變時重新載入
    private var reloadKey: String { selectedDepartment + "|" + searchText }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            departmentCapsules
            Divider()
            content
        }
        .navigationTitle("課程推薦")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadDepartments() }
        .task(id: reloadKey) {
            // 打字時稍等一下再查，不要每個字都打一次 API
            if !searchText.isEmpty {
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
            }
            await loadCourses()
        }
        .sheet(item: $detail) { course in
            CourseCommentsSheet(course: course, department: selectedDepartment)
        }
    }

    // MARK: - 搜尋框

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜尋課程名稱，例如：工程數學", text: $searchText)
                .focused($isSearchFocused)
                .submitLabel(.search)
                .onSubmit { isSearchFocused = false }
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - 科系膠囊（與校園地圖的校區膠囊同樣式）

    private var departmentCapsules: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(capsuleDepartments, id: \.self) { dept in
                    let isSelected = selectedDepartment == dept
                    Button {
                        withAnimation(.spring(duration: 0.3)) { selectedDepartment = dept }
                    } label: {
                        HStack(spacing: 4) {
                            if dept.isEmpty {
                                Text("全部")
                            } else {
                                if dept == store.departmentName {
                                    Image(systemName: "star.fill").font(.caption2)
                                }
                                Text(dept)
                            }
                        }
                        .font(.subheadline).bold()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color.teal : Color(.systemGray5))
                        .foregroundColor(isSelected ? .white : .primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    // MARK: - 列表

    @ViewBuilder
    private var content: some View {
        if isLoading && courses.isEmpty {
            ProgressView("載入中…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let loadError, courses.isEmpty {
            VStack(spacing: 14) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text(loadError)
                    .foregroundStyle(.secondary)
                Button("重試") { Task { await reloadAll() } }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if courses.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: searchText.isEmpty ? "hand.thumbsup" : "magnifyingglass")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(groupedCourses, id: \.name) { group in
                    Section {
                        ForEach(group.items) { course in
                            Button {
                                isSearchFocused = false
                                detail = course
                            } label: {
                                CourseRecommendRow(course: course)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        HStack {
                            Text(group.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .textCase(nil)
                            Spacer()
                            if group.items.count > 1 {
                                Text("\(group.items.count) 位老師")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollDismissesKeyboard(.immediately)
            .refreshable { await reloadAll() }
        }
    }

    private var emptyMessage: String {
        if !searchText.isEmpty { return "找不到「\(searchText)」的推薦\n可能還沒有同學評過這門課" }
        if selectedDepartment.isEmpty { return "還沒有人評分\n到成績頁點一門課，成為第一個推薦的人！" }
        return "\(selectedDepartment)還沒有同學評分"
    }

    // MARK: - 載入

    private func reloadAll() async {
        await loadDepartments()
        await loadCourses()
    }

    private func loadDepartments() async {
        if let list = try? await store.fetchDepartments() {
            withAnimation { departments = list }
        }
    }

    private func loadCourses() async {
        isLoading = true
        do {
            let result = try await store.browse(department: selectedDepartment, query: searchText)
            withAnimation(.easeOut(duration: 0.2)) { courses = result }
            loadError = nil
        } catch is CancellationError {
            return
        } catch let error as URLError where error.code == .cancelled {
            return
        } catch {
            loadError = "目前無法取得課程推薦"
        }
        isLoading = false
    }
}

// MARK: - 一門課（某位老師）的列

private struct CourseRecommendRow: View {
    let course: BrowseCourse

    private var summary: RatingSummary { course.summary }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(course.teacher.isEmpty ? "老師未提供" : course.teacher, systemImage: "person.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                if let type = summary.courseTypeLabel {
                    Text(type)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(typeColor(type))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(typeColor(type).opacity(0.12))
                        .clipShape(Capsule())
                }

                Spacer()

                if let rate = summary.recommendRate {
                    HStack(spacing: 5) {
                        RatingDot(color: recommendRateColor(rate))
                        Text("\(Int((rate * 100).rounded()))% 推薦")
                    }
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(recommendRateColor(rate))
                }
            }

            LevelStackBar(summary: summary)

            HStack(spacing: 12) {
                Text("\(summary.total) 人評分")
                if let comments = summary.comments, comments > 0 {
                    Label("\(comments) 則心得", systemImage: "text.bubble")
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func typeColor(_ type: String) -> Color {
        switch type {
        case "必修": return .blue
        case "選修": return .purple
        default:     return .gray
        }
    }
}

/// 四個等級的比例條（超級推薦 → 還可以 → 普普通通 → 拉完了）
private struct LevelStackBar: View {
    let summary: RatingSummary

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(RatingLevel.allCases) { level in
                    let count = summary.count(of: level) ?? 0
                    if count > 0 {
                        Rectangle()
                            .fill(level.color)
                            .frame(width: max(4, geo.size.width * CGFloat(count) / CGFloat(max(summary.total, 1)) - 2))
                    }
                }
            }
        }
        .frame(height: 6)
        .clipShape(Capsule())
        .background(Capsule().fill(Color(.systemGray5)))
        .accessibilityHidden(true)
    }
}

// MARK: - 課程心得頁

struct CourseCommentsSheet: View {
    let course: BrowseCourse
    /// 目前選的科系（空字串 = 全校）
    let department: String

    @Environment(\.dismiss) private var dismiss

    @State private var comments: [CourseComment] = []
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var reportTarget: CourseComment?
    @State private var blockTarget: CourseComment?
    @State private var toast: String?

    private var store: CourseRatingStore { .shared }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(course.name)
                            .font(.title3.weight(.bold))
                        Label("授課教師：\(course.teacher.isEmpty ? "未提供" : course.teacher)", systemImage: "person.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let type = course.summary.courseTypeLabel {
                            Text(department.isEmpty ? "修別：\(type)" : "\(department)修別：\(type)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    RatingBreakdownView(summary: course.summary,
                                        who: department.isEmpty ? "全校同學" : "\(department)同學")
                        .padding(.vertical, 4)
                }

                Section {
                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else if let loadError {
                        Text(loadError).foregroundStyle(.secondary)
                    } else if comments.isEmpty {
                        Text("還沒有同學留下心得")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(comments) { comment in
                            CommentRow(comment: comment)
                                .swipeActions(edge: .trailing) {
                                    Button("檢舉", systemImage: "exclamationmark.bubble") { reportTarget = comment }
                                        .tint(.orange)
                                    Button("封鎖", systemImage: "hand.raised") { blockTarget = comment }
                                        .tint(.red)
                                }
                                .contextMenu {
                                    Button("檢舉這則心得", systemImage: "exclamationmark.bubble") { reportTarget = comment }
                                    Button("封鎖這位匿名同學", systemImage: "hand.raised", role: .destructive) { blockTarget = comment }
                                }
                        }
                    }
                } header: {
                    Text(department.isEmpty ? "修課心得" : "\(department)同學的修課心得")
                } footer: {
                    Text("心得皆為匿名發表。長按或向左滑可以檢舉、封鎖；被多位同學檢舉的心得會自動隱藏。")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("課程心得")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { dismiss() }
                }
            }
            .overlay(alignment: .bottom) {
                if let toast {
                    Text(toast)
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.regularMaterial)
                        .clipShape(Capsule())
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .refreshable { await load() }
            .task { await load() }
            // 檢舉：選原因
            .confirmationDialog("檢舉原因",
                                isPresented: Binding(get: { reportTarget != nil },
                                                     set: { if !$0 { reportTarget = nil } }),
                                titleVisibility: .visible,
                                presenting: reportTarget) { comment in
                ForEach(["人身攻擊或謾罵", "不實或誤導內容", "洩漏個人資料", "廣告或與課程無關"], id: \.self) { reason in
                    Button(reason) { Task { await report(comment, reason: reason) } }
                }
                Button("取消", role: .cancel) {}
            } message: { _ in
                Text(store.studentId.isEmpty ? "請先登入後再檢舉" : "多位同學檢舉後，這則心得會自動隱藏")
            }
            // 封鎖：確認
            .confirmationDialog("封鎖這位匿名同學？",
                                isPresented: Binding(get: { blockTarget != nil },
                                                     set: { if !$0 { blockTarget = nil } }),
                                titleVisibility: .visible,
                                presenting: blockTarget) { comment in
                Button("封鎖", role: .destructive) {
                    store.block(author: comment.author)
                    withAnimation { comments.removeAll { $0.author == comment.author } }
                    showToast("已封鎖，之後不會再看到這位同學的心得")
                }
                Button("取消", role: .cancel) {}
            } message: { _ in
                Text("之後在這支手機上，所有課程都不會再顯示他的心得")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func load() async {
        do {
            comments = try await store.comments(name: course.name, teacher: course.teacher, department: department)
            loadError = nil
        } catch {
            loadError = "目前無法取得心得"
        }
        isLoading = false
    }

    private func report(_ comment: CourseComment, reason: String) async {
        do {
            let hidden = try await store.report(comment, reason: reason)
            if hidden {
                withAnimation { comments.removeAll { $0.id == comment.id } }
            }
            showToast("已收到檢舉，謝謝你")
        } catch {
            showToast(store.studentId.isEmpty ? "請先登入後再檢舉" : "檢舉失敗，請稍後再試")
        }
    }

    private func showToast(_ message: String) {
        withAnimation { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation { toast = nil }
        }
    }
}

private struct CommentRow: View {
    let comment: CourseComment

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "person.crop.circle.fill")
                    .foregroundStyle(.secondary)
                Text(authorName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let level = comment.ratingLevel {
                    HStack(spacing: 5) {
                        RatingDot(level, size: 7)
                        Text(level.title)
                    }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(level.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(level.color.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            Text(comment.text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Text("\(comment.year)-\(comment.term) 修課")
                if !comment.courseType.isEmpty { Text("・\(comment.courseType)") }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    /// 「電子工程系・匿名同學 #a3f9c1」
    private var authorName: String {
        let dept = comment.department.isEmpty ? "" : "\(comment.department)・"
        return "\(dept)匿名同學 #\(comment.author)"
    }
}

#Preview {
    NavigationStack {
        CourseRecommendView()
    }
}
