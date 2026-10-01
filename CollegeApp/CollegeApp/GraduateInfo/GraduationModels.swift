//
//  GraduationModels.swift
//  CollegeApp
//
//  Created by Wesley on 2026/10/1.
//
//  畢業修課狀況預覽的資料模型
//

import Foundation

// MARK: - 單一課群 / 科目項目（樹狀結構）
struct CreditItem: Identifiable {

    /// 對應網頁上的圖示：藍✓ 通過 / 橘☑ 修習後通過 / 紅✗ 未通過 / 藍ⓘ 資訊
    enum Status {
        case passed
        case conditional
        case failed
        case info
        case unknown
    }

    let id = UUID()
    let name: String
    let status: Status
    let required: Int?      // 需通過學分數
    let earned: Int?        // 已通過學分數
    let requiredCourses: Int?  // 需通過課程數（體育、博雅通識這類用課程數計算）
    let passedCourses: Int?    // 已通過課程數
    let children: [CreditItem]

    /// 給 SwiftUI `List(children:)` 使用，沒有下一層時回傳 nil
    var childrenOrNil: [CreditItem]? {
        children.isEmpty ? nil : children
    }

    /// 這一層以及所有子層中，未通過的「最底層」項目
    var failedLeaves: [CreditItem] {
        if children.isEmpty {
            return status == .failed ? [self] : []
        }
        return children.flatMap(\.failedLeaves)
    }
}

// MARK: - 其他課規外修習課程
// 資料來自 HierarchyStudyCheckView 裡 Kendo Grid 內嵌的 JSON。
// 原始 JSON 還包含大量個資（學生、家長資料等），這裡只解碼需要的欄位，其餘全部忽略。
nonisolated struct OtherCourse: Identifiable, Decodable {
    let electiveKey: Int
    let schoolYear: Int
    let semester: Int
    let selectType: String?
    let credit: Double?
    let orgCredit: Double?
    let openClassName: String?
    let openDeptName: String?
    let courseName: String?
    let perCrsno: String?
    let gradeScoreText: String?
    let withdraw: String?
    let isGraduCredit: Bool?
    let isTotallyPass: Bool?
    let vaildKindName: String?

    var id: Int { electiveKey }

    enum CodingKeys: String, CodingKey {
        case electiveKey    = "ElectiveKey"
        case schoolYear     = "SchoolYear"
        case semester       = "Semester"
        case selectType     = "SelectType"
        case credit         = "Credit"
        case orgCredit      = "OrgCredit"
        case openClassName  = "OpenClassName"
        case openDeptName   = "OpenDeptName"
        case courseName     = "CourseName"
        case perCrsno       = "PerCrsno"
        case gradeScoreText = "GradeScoreText"
        case withdraw       = "Withdraw"
        case isGraduCredit  = "IsGraduCredit"
        case isTotallyPass  = "IsTotallyPass"
        case vaildKindName  = "VaildKindName"
    }

    // MARK: 顯示用

    /// 學期文字：1 → 上學期、2 → 下學期、4 → 暑修
    var semesterText: String {
        switch semester {
        case 1: return "上學期"
        case 2: return "下學期"
        case 3: return "寒修"
        case 4: return "暑修"
        default: return "第\(semester)學期"
        }
    }

    /// 學年學期，例如「113 暑修」
    var termText: String { "\(schoolYear) \(semesterText)" }

    /// 修別：M → 必修、O → 選修
    var selectTypeText: String {
        switch selectType {
        case "M": return "必修"
        case "O": return "選修"
        default:  return selectType ?? ""
        }
    }

    /// 學分；抵充（Withdraw == "3"）時顯示「原學分(充 x)」
    var creditText: String {
        let org = Self.format(orgCredit ?? credit ?? 0)
        if withdraw == "3", let c = credit {
            return "\(org)(充\(Self.format(c)))"
        }
        return org
    }

    /// 成績；還沒有成績時視為修習中
    var gradeText: String {
        let text = (gradeScoreText ?? "").trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? "修習中" : text
    }

    var isInProgress: Bool {
        (gradeScoreText ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// 審認註記；「---」代表尚未審認
    var reviewText: String {
        let text = (vaildKindName ?? "").trimmingCharacters(in: .whitespaces)
        return (text.isEmpty || text == "---") ? "尚未審認" : text
    }

    private static func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}

/// Kendo Grid 的資料格式：{"Data":[...],"Total":7}
nonisolated struct KendoGridResponse<T: Decodable>: Decodable {
    let data: [T]
    let total: Int?

    enum CodingKeys: String, CodingKey {
        case data  = "Data"
        case total = "Total"
    }
}

// MARK: - 校定英語畢業門檻
struct EnglishThreshold {
    let resultText: String   // 例如「審查通過」
    let isPassed: Bool
}

// MARK: - 整份畢業修課狀況
struct GraduationStatus {
    /// 課規課群比對結果
    var groups: [CreditItem] = []
    /// 修課學分結果預覽
    var summary: [CreditItem] = []
    /// 其他課規外修習課程
    var otherCourses: [OtherCourse] = []
    /// 校定英語畢業門檻
    var englishThreshold: EnglishThreshold? = nil

    /// 畢業審查學分數（例如 需通過 128 / 已通過 130）
    var total: CreditItem? { summary.first }

    /// 所有未通過的最底層項目（例如「科技與數位知能」、「通識微學分」）
    var unmetItems: [CreditItem] {
        groups.flatMap(\.failedLeaves)
    }

    /// 是否所有條件都通過
    var isAllPassed: Bool {
        !groups.isEmpty && groups.allSatisfy { $0.status == .passed }
    }
}

// MARK: - 錯誤
enum GraduationError: Error {
    case sessionExpired
    case invalidResponse
    case sectionNotFound
}
