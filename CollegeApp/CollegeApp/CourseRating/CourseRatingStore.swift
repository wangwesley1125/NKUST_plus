//
//  CourseRatingStore.swift
//  CollegeApp
//
//  課程推薦：
//  - 本機（SwiftData / SQLite）：記住「我自己評過什麼、寫了什麼心得」，沒網路也看得到；送出失敗會留著下次補傳
//  - 雲端（Cloudflare Workers + D1）：彙總所有人的推薦、修課心得（匿名，只存學號雜湊）
//

import SwiftUI
import SwiftData
import Observation

// MARK: - API 設定

enum CourseRatingAPI {
    static let baseURL = URL(string: "https://nkust-plus-ratings.nkust-plus.workers.dev")!

    /// 修課心得字數上限（需與後端 COMMENT_MAX_LENGTH 一致）
    static let commentMaxLength = 200
}

// MARK: - 推薦程度

enum RatingLevel: Int, CaseIterable, Identifiable {
    case superb = 4   // 超級推薦
    case good   = 3   // 還可以
    case meh    = 2   // 普普通通
    case awful  = 1   // 拉完了

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .superb: return "超級推薦"
        case .good:   return "還可以"
        case .meh:    return "普普通通"
        case .awful:  return "拉完了"
        }
    }

    /// 圓點顏色：超級推薦 粉紅、還可以 綠、普普通通 橘、拉完了 咖啡
    var color: Color {
        switch self {
        case .superb: return .pink
        case .good:   return .green
        case .meh:    return .orange
        case .awful:  return .brown
        }
    }
}

/// 推薦程度的小圓點（取代 emoji，全 App 共用）
struct RatingDot: View {
    let color: Color
    var size: CGFloat = 8

    init(_ level: RatingLevel, size: CGFloat = 8) {
        self.color = level.color
        self.size = size
    }

    init(color: Color, size: CGFloat = 8) {
        self.color = color
        self.size = size
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// 推薦率對應的顏色（推薦頁、首頁共用）：沿用四個等級的顏色
func recommendRateColor(_ rate: Double) -> Color {
    switch rate {
    case 0.7...:     return RatingLevel.superb.color
    case 0.4..<0.7:  return RatingLevel.good.color
    case 0.2..<0.4:  return RatingLevel.meh.color
    default:         return RatingLevel.awful.color
    }
}

// MARK: - 伺服器回傳的資料

/// 一組評分統計（全校、單一科系、或推薦頁的一門課）
struct RatingSummary: Decodable, Hashable {
    let total: Int
    let hidden: Bool
    /// [拉完了, 普普通通, 還可以, 超級推薦] 的人數
    let levels: [Int]?
    /// 超級推薦 + 還可以 的人數
    let recommended: Int?
    /// 評分者成績單上是必修 / 選修的人數
    let required: Int?
    let elective: Int?
    /// 可見的修課心得數
    let comments: Int?
    /// 科系名稱（全校統計時為 nil）
    let department: String?

    /// 推薦比例 0...1
    var recommendRate: Double? {
        guard !hidden, let recommended, total > 0 else { return nil }
        return Double(recommended) / Double(total)
    }

    func count(of level: RatingLevel) -> Int? {
        guard let levels, levels.count == 4 else { return nil }
        return levels[level.rawValue - 1]
    }

    /// 修別標籤：只有必修 → 必修、只有選修 → 選修、兩種都有 → 依科系不同
    var courseTypeLabel: String? {
        let r = required ?? 0, e = elective ?? 0
        switch (r > 0, e > 0) {
        case (true, false): return "必修"
        case (false, true): return "選修"
        case (true, true):  return "必選修皆有"
        default:            return nil
        }
    }
}

/// /v1/stats：最外層是全校，dept 是本系（有帶科系查詢時才有）
struct CourseStat: Decodable, Hashable {
    let name: String
    let teacher: String
    let total: Int
    let hidden: Bool
    let levels: [Int]?
    let recommended: Int?
    let required: Int?
    let elective: Int?
    let comments: Int?
    let dept: RatingSummary?

    var overall: RatingSummary {
        RatingSummary(total: total, hidden: hidden, levels: levels, recommended: recommended,
                      required: required, elective: elective, comments: comments, department: nil)
    }

    /// 全校推薦比例（MainView 徽章用）
    var recommendRate: Double? { overall.recommendRate }
}

/// /v1/departments
struct DepartmentInfo: Decodable, Hashable {
    let department: String
    let total: Int
}

/// /v1/browse：推薦頁的一門課（課名 + 老師）
struct BrowseCourse: Decodable, Identifiable, Hashable {
    let name: String
    let teacher: String
    let total: Int
    let hidden: Bool
    let levels: [Int]?
    let recommended: Int?
    let required: Int?
    let elective: Int?
    let comments: Int?

    var id: String { name + "|" + teacher }

    var summary: RatingSummary {
        RatingSummary(total: total, hidden: hidden, levels: levels, recommended: recommended,
                      required: required, elective: elective, comments: comments, department: nil)
    }
}

/// /v1/comments：一則修課心得
struct CourseComment: Decodable, Identifiable, Hashable {
    let id: Int
    /// 匿名代號（6 碼），同一人在各門課相同，用來封鎖
    let author: String
    let year: String
    let term: String
    let department: String
    let courseType: String
    let level: Int
    let text: String
    let updatedAt: String

    var ratingLevel: RatingLevel? { RatingLevel(rawValue: level) }
}

/// 送出評分的結果
enum RatingSubmitResult: Equatable {
    case success
    /// 沒網路：已存在手機，之後補傳
    case savedOffline
    /// 伺服器拒絕留言（不當用語、網址、太長）：本機已還原，可以修改後再送
    case rejected(String)
    /// 這門課已經推薦過了（每門課只能推薦一次）
    case alreadyRated
}

// MARK: - 文字正規化（與後端一致）

/// NFKC（全形轉半形）+ 去掉所有空白
func normalizeCourseText(_ s: String) -> String {
    s.precomposedStringWithCompatibilityMapping
        .unicodeScalars
        .filter { !CharacterSet.whitespacesAndNewlines.contains($0) }
        .map(String.init)
        .joined()
}

/// 「課名 + 老師」的查詢 key
func courseStatKey(name: String, teacher: String) -> String {
    normalizeCourseText(name) + "|" + normalizeCourseText(teacher)
}

/// 科系：「電子工程系[建工|燕巢]」→「電子工程系」
func normalizeDepartmentName(_ s: String) -> String {
    let base = normalizeCourseText(s)
    let stripped = base.replacingOccurrences(of: #"\[[^\]]*\]"#, with: "", options: .regularExpression)
    return String(stripped.prefix(30))
}

// MARK: - 本機紀錄（SwiftData）

@Model
final class MyCourseRating {
    /// 學年-學期-課名（正規化），例如 115-1-工程數學
    /// （不設 unique：同一支手機換帳號時，不同學號可以各自評同一門課）
    var courseKey: String
    /// 這筆是哪個帳號評的（學號，只存在手機本機），換帳號時互不影響
    var owner: String = ""
    var year: String
    var term: String
    var courseCode: String
    var courseName: String
    var teacher: String
    /// 必修 / 選修（成績單上的修別）
    var courseType: String = ""
    /// 1~4 = 推薦程度
    var level: Int = 0
    /// 修課心得
    var comment: String = ""
    var isSynced: Bool
    var updatedAt: Date

    init(owner: String, courseKey: String, year: String, term: String, courseCode: String,
         courseName: String, teacher: String, courseType: String, level: Int, comment: String) {
        self.owner = owner
        self.courseKey = courseKey
        self.year = year
        self.term = term
        self.courseCode = courseCode
        self.courseName = courseName
        self.teacher = teacher
        self.courseType = courseType
        self.level = level
        self.comment = comment
        self.isSynced = false
        self.updatedAt = .now
    }
}

// MARK: - Store

@MainActor
@Observable
final class CourseRatingStore {
    static let shared = CourseRatingStore()

    /// 目前登入者學號（MainView / ScoreView 載入學籍資料後設定）
    var studentId: String = "" {
        didSet {
            guard studentId != oldValue else { return }
            // 換帳號：只顯示這個學號自己的評分
            reloadRatings()
            if !studentId.isEmpty {
                Task { await syncPending() }
            }
        }
    }

    /// 學籍資料上的科系，評分時一起送出，只用來分科系統計
    var department: String = ""

    /// 畫面顯示用的科系名稱（例如「電子工程系」）；抓不到時為空字串
    var departmentName: String { normalizeDepartmentName(department) }

    /// courseKey → 我的推薦程度（給 UI 即時顯示）
    private(set) var myRatings: [String: RatingLevel] = [:]
    /// 正在送出的課
    private(set) var submitting: Set<String> = []
    /// 已封鎖的匿名同學代號（只存在這支手機）
    private(set) var blockedAuthors: Set<String>

    @ObservationIgnored private let context: ModelContext?
    private static let blockedKey = "blockedCommentAuthors"

    private init() {
        // 自己建一個獨立的容器，不需要改 App 進入點
        if let container = try? ModelContainer(for: MyCourseRating.self) {
            context = ModelContext(container)
        } else {
            context = nil
        }
        blockedAuthors = Set(UserDefaults.standard.stringArray(forKey: Self.blockedKey) ?? [])
        reloadRatings()
    }

    /// 同一學期同一門課（課名）＝同一筆，與後端一致；
    /// 成績頁（有課號）和歷年成績（沒有課號）推薦同一門課會被視為同一筆
    static func courseKey(year: String, term: String, courseName: String) -> String {
        "\(year)-\(term)-\(normalizeCourseText(courseName))"
    }

    func rating(for courseKey: String) -> RatingLevel? {
        myRatings[courseKey]
    }

    /// 推薦過了就不能再推薦（按鈕 disabled）
    func isRated(_ courseKey: String) -> Bool {
        myRatings[courseKey] != nil
    }

    /// 我在這門課寫過的心得（評分卡片預先帶入）
    func myComment(for courseKey: String) -> String {
        fetch(courseKey)?.comment ?? ""
    }

    // MARK: 評分

    /// 推薦一門課（每門課只能一次）。
    /// 先存本機（按鈕立刻變「已推薦」），再送伺服器；沒網路就留著下次補傳；
    /// 留言被拒就把本機紀錄刪掉，讓使用者修改後再送。
    func setRating(_ level: RatingLevel,
                   comment: String,
                   year: String, term: String, courseCode: String,
                   courseName: String, teacher: String, courseType: String) async -> RatingSubmitResult {
        guard !studentId.isEmpty else { return .savedOffline }
        let key = Self.courseKey(year: year, term: term, courseName: courseName)
        if fetch(key) != nil { return .alreadyRated }

        let record = MyCourseRating(owner: studentId,
                                    courseKey: key, year: year, term: term, courseCode: courseCode,
                                    courseName: courseName, teacher: teacher, courseType: courseType,
                                    level: level.rawValue,
                                    comment: comment.trimmingCharacters(in: .whitespacesAndNewlines))
        context?.insert(record)
        try? context?.save()
        myRatings[key] = level

        let result = await upload(record)

        if case .rejected = result {
            context?.delete(record)
            try? context?.save()
            myRatings[key] = nil
        }
        return result
    }

    /// 把之前送失敗的補傳
    func syncPending() async {
        guard let context, !studentId.isEmpty else { return }
        let owner = studentId
        let descriptor = FetchDescriptor<MyCourseRating>(predicate: #Predicate { !$0.isSynced && $0.owner == owner })
        guard let pending = try? context.fetch(descriptor) else { return }
        for record in pending {
            if case .rejected = await upload(record) {
                // 補傳時心得被拒（例如規則變嚴）：保留推薦、清掉心得，下次再送
                record.comment = ""
                try? context.save()
            }
        }
    }

    // MARK: 查詢推薦數（MainView、評分卡片）

    /// 單門課（評分卡片用，會一起查本系的數字）
    func fetchStat(name: String, teacher: String) async -> CourseStat? {
        await fetchStats(for: [(name: name, teacher: teacher)], includeDepartment: true)[
            courseStatKey(name: name, teacher: teacher)
        ]
    }

    /// 批次查詢（一次最多 30 門），回傳 key = courseStatKey(name:teacher:)
    func fetchStats(for courses: [(name: String, teacher: String)],
                    includeDepartment: Bool = false) async -> [String: CourseStat] {
        var seen = Set<String>()
        let unique = courses.filter { seen.insert(courseStatKey(name: $0.name, teacher: $0.teacher)).inserted }
        guard !unique.isEmpty else { return [:] }

        var result: [String: CourseStat] = [:]
        for start in stride(from: 0, to: unique.count, by: 30) {
            let chunk = Array(unique[start..<min(start + 30, unique.count)])
            var body: [String: Any] = [
                "courses": chunk.map { ["name": $0.name, "teacher": $0.teacher] }
            ]
            if includeDepartment, !departmentName.isEmpty {
                body["department"] = department
            }
            guard let data = try? await post("/v1/stats", body: body),
                  let decoded = try? JSONDecoder().decode(StatsResponse.self, from: data) else { continue }

            // 伺服器回傳順序與請求相同
            for (course, stat) in zip(chunk, decoded.stats) {
                result[courseStatKey(name: course.name, teacher: course.teacher)] = stat
            }
        }
        return result
    }

    // MARK: 課程推薦頁

    /// 有人評分過的科系（膠囊按鈕）
    func fetchDepartments() async throws -> [DepartmentInfo] {
        let data = try await get("/v1/departments")
        return try JSONDecoder().decode(DepartmentsResponse.self, from: data).departments
    }

    /// 推薦列表；department 空字串 = 全校；query = 課名關鍵字
    func browse(department: String, query: String) async throws -> [BrowseCourse] {
        var items: [URLQueryItem] = [URLQueryItem(name: "limit", value: "100")]
        if !department.isEmpty { items.append(URLQueryItem(name: "department", value: department)) }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty { items.append(URLQueryItem(name: "q", value: q)) }
        let data = try await get("/v1/browse", query: items)
        return try JSONDecoder().decode(BrowseResponse.self, from: data).courses
    }

    /// 某門課的修課心得（已過濾掉被我封鎖的同學）
    func comments(name: String, teacher: String, department: String) async throws -> [CourseComment] {
        var items = [URLQueryItem(name: "name", value: name), URLQueryItem(name: "teacher", value: teacher)]
        if !department.isEmpty { items.append(URLQueryItem(name: "department", value: department)) }
        let data = try await get("/v1/comments", query: items)
        let all = try JSONDecoder().decode(CommentsResponse.self, from: data).comments
        return all.filter { !blockedAuthors.contains($0.author) }
    }

    /// 檢舉留言；回傳是否已被隱藏
    @discardableResult
    func report(_ comment: CourseComment, reason: String) async throws -> Bool {
        guard !studentId.isEmpty else { throw URLError(.userAuthenticationRequired) }
        let data = try await post("/v1/comments/report",
                                  body: ["id": comment.id, "studentId": studentId, "reason": reason])
        return (try? JSONDecoder().decode(ReportResponse.self, from: data).hidden) ?? false
    }

    /// 封鎖某位匿名同學：之後在這支手機上看不到他的心得
    func block(author: String) {
        blockedAuthors.insert(author)
        UserDefaults.standard.set(Array(blockedAuthors), forKey: Self.blockedKey)
    }

    func unblockAll() {
        blockedAuthors.removeAll()
        UserDefaults.standard.removeObject(forKey: Self.blockedKey)
    }

    // MARK: - 私有

    private struct StatsResponse: Decodable { let stats: [CourseStat] }
    private struct DepartmentsResponse: Decodable { let departments: [DepartmentInfo] }
    private struct BrowseResponse: Decodable { let courses: [BrowseCourse] }
    private struct CommentsResponse: Decodable { let comments: [CourseComment] }
    private struct ReportResponse: Decodable { let hidden: Bool }
    private struct ErrorResponse: Decodable { let error: String; let code: String? }

    private enum APIError: Error {
        case rejected(String)
        case alreadyRated(level: Int?, comment: String?)
    }

    private struct AlreadyRatedResponse: Decodable { let level: Int?; let comment: String? }

    @discardableResult
    private func upload(_ record: MyCourseRating) async -> RatingSubmitResult {
        guard !studentId.isEmpty else { return .savedOffline }   // 還沒拿到學號，先存本機
        let key = record.courseKey
        submitting.insert(key)
        defer { submitting.remove(key) }

        var body: [String: Any] = [
            "studentId": studentId,
            "year": record.year,
            "term": record.term,
            "courseName": record.courseName,
            "teacher": record.teacher,
            "department": department,
            "courseType": record.courseType,
            "level": record.level,
            "comment": record.comment
        ]
        if !record.courseCode.isEmpty { body["courseCode"] = record.courseCode }

        do {
            _ = try await post("/v1/ratings", body: body)
            record.isSynced = true
            try? context?.save()
            return .success
        } catch APIError.rejected(let message) {
            return .rejected(message)
        } catch APIError.alreadyRated(let level, let comment) {
            // 伺服器已有這門課的推薦（例如重灌 App 後）：以伺服器為準，本機也標成已推薦
            if let level, let rating = RatingLevel(rawValue: level) {
                record.level = level
                myRatings[key] = rating
            }
            if let comment { record.comment = comment }
            record.isSynced = true
            try? context?.save()
            return .alreadyRated
        } catch {
            print("推薦送出失敗，稍後補傳：\(error)")
            return .savedOffline
        }
    }

    private func post(_ path: String, body: [String: Any]) async throws -> Data {
        var request = URLRequest(url: CourseRatingAPI.baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await send(request)
    }

    private func get(_ path: String, query: [URLQueryItem] = []) async throws -> Data {
        var url = CourseRatingAPI.baseURL.appending(path: path)
        if !query.isEmpty { url.append(queryItems: query) }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData   // 即時資料，不用快取
        return try await send(request)
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if (200..<300).contains(http.statusCode) { return data }

        // 409：這門課已經推薦過了
        if http.statusCode == 409 {
            let existing = try? JSONDecoder().decode(AlreadyRatedResponse.self, from: data)
            throw APIError.alreadyRated(level: existing?.level, comment: existing?.comment)
        }

        // 400 且是留言被拒：把伺服器的原因（中文）帶回畫面
        if http.statusCode == 400,
           let err = try? JSONDecoder().decode(ErrorResponse.self, from: data),
           err.code == "comment_rejected" {
            throw APIError.rejected(err.error)
        }
        throw URLError(.badServerResponse)
    }

    private func fetch(_ key: String) -> MyCourseRating? {
        let owner = studentId
        var descriptor = FetchDescriptor<MyCourseRating>(predicate: #Predicate { $0.courseKey == key && $0.owner == owner })
        descriptor.fetchLimit = 1
        return try? context?.fetch(descriptor).first
    }

    private func reloadRatings() {
        let owner = studentId
        guard let context, !owner.isEmpty,
              let all = try? context.fetch(FetchDescriptor<MyCourseRating>(predicate: #Predicate { $0.owner == owner }))
        else {
            myRatings = [:]
            return
        }
        var ratings: [String: RatingLevel] = [:]
        for r in all {
            if let level = RatingLevel(rawValue: r.level) { ratings[r.courseKey] = level }
        }
        myRatings = ratings
    }
}
