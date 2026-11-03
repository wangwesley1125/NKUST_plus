//
//  CourseRatingSheet.swift
//  CollegeApp
//
//  按成績頁 / 歷年成績的「推薦」按鈕後跳出的評分卡片：
//  課名 / 老師 → 膠囊選項（超級推薦、還可以、普普通通、拉完了，各有一個顏色圓點）
//  → 修課心得 → 目前統計（全校 / 本系）→ 匿名說明 → 送出（每門課只能一次）
//

import SwiftUI

// MARK: - 可以推薦的一門課（成績頁、歷年成績共用）

struct RatableCourse: Identifiable, Hashable {
    let year: String
    let term: String
    /// 歷年成績（PDF）沒有課號 → 空字串
    let courseCode: String
    let name: String
    /// 必修 / 選修
    let type: String

    var id: String { courseKey }
    var courseKey: String { CourseRatingStore.courseKey(year: year, term: term, courseName: name) }
}

extension RatableCourse {
    /// 成績頁（期中 / 當學期）
    init(_ record: ScoreRecord) {
        self.init(year: record.year, term: record.term, courseCode: record.courseCode,
                  name: record.name, type: record.type)
    }

    /// 歷年成績：semester 例如「113-1」
    init?(_ course: CourseRecord, semester: String) {
        let parts = semester.split(separator: "-").map(String.init)
        guard parts.count == 2 else { return nil }
        self.init(year: parts[0], term: parts[1], courseCode: "", name: course.name, type: course.type)
    }
}

// MARK: - 「推薦」按鈕（推薦過就變灰色「已推薦」，不能再按）

struct RecommendButton: View {
    let courseKey: String
    let action: () -> Void

    private var store: CourseRatingStore { .shared }

    var body: some View {
        let rated = store.isRated(courseKey)
        let busy = store.submitting.contains(courseKey)

        Button(action: action) {
            Group {
                if busy {
                    ProgressView().controlSize(.mini).tint(.white)
                } else {
                    Text(rated ? "已推薦" : "推薦")
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(rated ? Color.secondary : Color.white)
            .frame(width: 50, height: 26)
            .background(Capsule().fill(rated ? Color(.systemGray5) : Color.teal))
        }
        // borderless：在 List 裡只有按鈕本身可以點，不會整列都觸發
        .buttonStyle(.borderless)
        .disabled(rated || busy || store.studentId.isEmpty)
        .accessibilityLabel(rated ? "已推薦過這門課" : "推薦這門課")
    }
}

// MARK: - 評分卡片

struct CourseRatingSheet: View {
    let course: RatableCourse
    /// 從課表偵測到的老師（對不到時為空字串），會自動填進「授課教師」欄位
    let teacher: String

    init(course: RatableCourse, teacher: String) {
        self.course = course
        self.teacher = teacher
        _teacherName = State(initialValue: teacher)
    }

    @Environment(\.dismiss) private var dismiss

    /// 授課教師：自動帶入或使用者自己填
    @State private var teacherName: String
    /// 其他同學填過的老師（點一下帶入，讓大家寫法一致）
    @State private var teacherSuggestions: [String] = []
    @FocusState private var isTeacherFocused: Bool

    @State private var selected: RatingLevel?
    @State private var comment = ""
    @State private var stat: CourseStat?
    @State private var isLoadingStat = true
    @State private var isSubmitting = false
    @State private var errorText: String?
    /// 統計顯示：false = 全校、true = 本系
    @State private var showDepartment = false
    @FocusState private var isCommentFocused: Bool

    private var store: CourseRatingStore { .shared }

    private var courseKey: String { course.courseKey }
    private var current: RatingLevel? { store.rating(for: courseKey) }
    /// 學號還沒載入前不能評（伺服器需要學號雜湊判斷一人一票）
    private var canRate: Bool { !store.studentId.isEmpty }

    private var trimmedComment: String { comment.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var commentLength: Int { trimmedComment.count }
    private var commentTooLong: Bool { commentLength > CourseRatingAPI.commentMaxLength }

    private var trimmedTeacher: String { teacherName.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var teacherTooLong: Bool { trimmedTeacher.count > 40 }
    private var isAutoDetected: Bool { !teacher.isEmpty && trimmedTeacher == teacher }


    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    teacherSection
                    Divider()
                    levelPicker
                    commentSection
                    statsSection
                    anonymousRow
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) { actionBar }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        isCommentFocused = false
                        isTeacherFocused = false
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        // 其他同學填過的老師
        .task { await loadTeacherSuggestions() }
        // 老師改了就重新查統計（打字時稍等一下再查）
        .task(id: normalizeCourseText(teacherName)) {
            if trimmedTeacher != teacher {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
            }
            let result = await store.fetchStat(name: course.name, teacher: trimmedTeacher)
            guard !Task.isCancelled else { return }
            stat = result
            // 本系有人評就預設顯示本系，比較貼近自己
            if isLoadingStat, let dept = result?.dept, dept.total > 0 { showDepartment = true }
            isLoadingStat = false
        }
    }

    // MARK: - 課名 / 老師

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(course.name)
                .font(.title2.weight(.bold))

            Text(course.courseCode.isEmpty
                 ? "\(course.year) 學年第 \(course.term) 學期・\(course.type)"
                 : "\(course.year) 學年第 \(course.term) 學期・課號 \(course.courseCode)・\(course.type)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - 授課教師

    private var teacherSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("授課教師")
                    .font(.headline)
                if isAutoDetected {
                    Label("已從課表自動帶入", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.teal)
                } else {
                    Text("（選填）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "person.fill")
                    .foregroundStyle(.secondary)
                TextField("例如：王小明，多位老師用「、」分開", text: $teacherName)
                    .focused($isTeacherFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
                    .onSubmit { isTeacherFocused = false }
                if !teacherName.isEmpty {
                    Button {
                        teacherName = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(teacherTooLong ? Color.red : Color(.separator), lineWidth: 1)
            )
            .disabled(!canRate || isSubmitting || current != nil)

            // 其他同學填過的老師：點一下帶入
            let others = teacherSuggestions.filter { normalizeCourseText($0) != normalizeCourseText(teacherName) }
            if !others.isEmpty, current == nil {
                Text("其他同學填過的老師")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(others, id: \.self) { name in
                            Button {
                                teacherName = name
                                isTeacherFocused = false
                            } label: {
                                Text(name)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .foregroundStyle(.teal)
                                    .background(Capsule().strokeBorder(Color.teal.opacity(0.5), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if teacherTooLong {
                Text("授課教師最多 40 字")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }

    private func loadTeacherSuggestions() async {
        let target = normalizeCourseText(course.name)
        guard let courses = try? await store.browse(department: "", query: course.name) else { return }
        var seen = Set<String>()
        teacherSuggestions = courses
            .filter { normalizeCourseText($0.name) == target && !$0.teacher.isEmpty }
            .sorted { $0.total > $1.total }                 // 評分多的老師排前面
            .map(\.teacher)
            .filter { seen.insert($0).inserted }
    }

    // MARK: - 膠囊選項

    private var levelPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("你會推薦這門課嗎？")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                      spacing: 10) {
                ForEach(RatingLevel.allCases) { level in
                    capsule(level)
                }
            }
            .sensoryFeedback(.selection, trigger: selected)

            if !canRate {
                Label("正在載入學籍資料，稍後即可評分", systemImage: "hourglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func capsule(_ level: RatingLevel) -> some View {
        let isSelected = selected == level
        return Button {
            withAnimation(.snappy(duration: 0.2)) { selected = level }
        } label: {
            HStack(spacing: 6) {
                // 選中時膠囊底色就是等級顏色，圓點改白色才看得到
                RatingDot(color: isSelected ? .white : level.color, size: 9)
                Text(level.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(
                Capsule().fill(isSelected ? level.color : Color(.secondarySystemFill))
            )
            .overlay(
                Capsule().strokeBorder(isSelected ? Color.clear : level.color.opacity(0.35), lineWidth: 1)
            )
            .scaleEffect(isSelected ? 1.03 : 1)
        }
        .buttonStyle(.plain)
        .disabled(!canRate || isSubmitting || current != nil)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - 修課心得

    private var commentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("你的修課心得")
                    .font(.headline)
                Text("（選填）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(commentLength)/\(CourseRatingAPI.commentMaxLength)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(commentTooLong ? .red : .secondary)
            }

            TextField("分享老師的教學方式、作業量、考試難度或修課建議…", text: $comment, axis: .vertical)
                .lineLimit(3...6)
                .focused($isCommentFocused)
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(commentTooLong ? Color.red : Color(.separator), lineWidth: 1)
                )
                .disabled(!canRate || isSubmitting || current != nil)

            Text("請針對課程內容分享，勿人身攻擊或透露他人個資。被多位同學檢舉的心得會自動隱藏。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 目前統計

    @ViewBuilder
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("同學們怎麼說")
                    .font(.headline)
                Spacer()
                if !store.departmentName.isEmpty {
                    Picker("統計範圍", selection: $showDepartment) {
                        Text("全校").tag(false)
                        Text("本系").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 130)
                }
            }

            if isLoadingStat {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let stat {
                let summary = (showDepartment ? stat.dept : nil) ?? stat.overall
                let who = showDepartment ? "\(store.departmentName)同學" : "全校同學"
                RatingBreakdownView(summary: summary, who: who)
            } else {
                Text("目前無法取得評分統計")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .animation(.snappy(duration: 0.2), value: showDepartment)
    }

    // MARK: - 匿名說明

    private var anonymousRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "eye.slash")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("匿名發表")
                    .font(.subheadline.weight(.semibold))
                Text(store.departmentName.isEmpty
                     ? "心得會顯示為「匿名同學」，其他同學看不到你是誰，也不會顯示學號"
                     : "心得會顯示為「\(store.departmentName)・匿名同學」，其他同學看不到你是誰，也不會顯示學號")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.teal)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    // MARK: - 底部按鈕

    private var actionBar: some View {
        VStack(spacing: 8) {
            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            } else {
                Text("每門課只能推薦一次，送出後無法修改")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Button {
                guard let selected else { return }
                Task { await submit(selected) }
            } label: {
                Group {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text(current == nil ? "送出推薦" : "已推薦")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(selected?.color ?? .teal)
            .controlSize(.large)
            .disabled(selected == nil || current != nil || commentTooLong || teacherTooLong || !canRate || isSubmitting)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.bar)
    }

    private func submit(_ level: RatingLevel) async {
        isCommentFocused = false
        isTeacherFocused = false
        isSubmitting = true
        errorText = nil
        let result = await store.setRating(
            level,
            comment: trimmedComment,
            year: course.year,
            term: course.term,
            courseCode: course.courseCode,
            courseName: course.name,
            teacher: trimmedTeacher,
            courseType: course.type
        )
        isSubmitting = false

        switch result {
        case .success:
            dismiss()
        case .savedOffline:
            errorText = "目前無法連線，已先存在手機，之後會自動補傳"
        case .rejected(let message):
            errorText = "\(message)，請修改後再送出"
        case .alreadyRated:
            errorText = "你已經推薦過這門課了"
        }
    }
}

// MARK: - 共用：各等級人數長條（評分卡片、課程推薦頁共用）

struct RatingBreakdownView: View {
    let summary: RatingSummary
    /// 例如「全校同學」「電子工程系同學」
    let who: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if summary.total > 0, !summary.hidden {
                HStack(spacing: 6) {
                    Text("共 \(summary.total) 位\(who)評分")
                    if let rate = summary.recommendRate {
                        Text("・\(Int((rate * 100).rounded()))% 推薦")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                ForEach(RatingLevel.allCases) { level in
                    let count = summary.count(of: level) ?? 0
                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            RatingDot(level)
                            Text(level.title)
                        }
                        .font(.caption)
                        .frame(width: 110, alignment: .leading)
                        ProgressView(value: Double(count), total: Double(max(summary.total, 1)))
                            .tint(level.color)
                        Text("\(count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .trailing)
                    }
                }
            } else {
                Text("還沒有\(who)評分，成為第一個吧！")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
