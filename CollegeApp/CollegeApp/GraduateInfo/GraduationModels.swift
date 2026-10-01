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

    /// 對應網頁上的圖示：藍✓ 通過 / 橘☑ 修習後通過 / 紅✗ 未通過
    enum Status {
        case passed
        case conditional
        case failed
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

// MARK: - 整份畢業修課狀況
struct GraduationStatus {
    /// 課規課群比對結果
    var groups: [CreditItem] = []
    /// 修課學分結果預覽
    var summary: [CreditItem] = []

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
