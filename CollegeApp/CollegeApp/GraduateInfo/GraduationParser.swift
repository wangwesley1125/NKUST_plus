//
//  GraduationParser.swift
//  CollegeApp
//
//  Created by Wesley on 2026/10/1.
//
//  解析 HierarchyStudyCheckView（課規課程修課學分狀況）
//  - 課規課群比對結果 / 修課學分結果預覽：<fieldset><legend> 底下的巢狀 <ul>
//  - 其他課規外修習課程：Kendo Grid 內嵌在 <script> 裡的 JSON
//  - 校定英語畢業門檻：<label id="langStatus">
//

import Foundation
import SwiftSoup

enum GraduationParser {

    // MARK: - 進入點
    static func parse(html: String) throws -> GraduationStatus {
        let doc = try SwiftSoup.parse(html)

        var result = GraduationStatus()
        result.groups  = try section(titled: "課規課群比對結果", in: doc)
        result.summary = try section(titled: "修課學分結果預覽", in: doc)

        if result.groups.isEmpty && result.summary.isEmpty {
            throw GraduationError.sectionNotFound
        }

        // 下面兩區解析失敗不影響主要資料
        result.otherCourses     = parseOtherCourses(html: html)
        result.englishThreshold = try? parseEnglishThreshold(in: doc)

        return result
    }

    // MARK: - 找到標題所在區塊，回傳底下第一層清單
    private static func section(titled title: String, in doc: Document) throws -> [CreditItem] {
        // 找到「自己的文字」含有標題的元素（例如 <legend> 裡的 <span>）
        guard var node: Element = try doc.select(":containsOwn(\(title))").first() else {
            return []
        }

        // 往上找，直到某一層的直接子元素中有 <ul>（最多找 5 層）
        for _ in 0..<5 {
            if let ul = node.children().first(where: { $0.tagName() == "ul" }) {
                return try parseList(ul)
            }
            guard let parent = node.parent() else { break }
            node = parent
        }
        return []
    }

    // MARK: - 解析 <ul>
    private static func parseList(_ ul: Element) throws -> [CreditItem] {
        try ul.children()
            .filter { $0.tagName() == "li" }
            .map { try parseItem($0) }
    }

    // MARK: - 解析單一 <li>（會遞迴處理子清單）
    private static func parseItem(_ li: Element) throws -> CreditItem {
        let childUL = li.children().first { $0.tagName() == "ul" }

        // 複製一份並移除子清單，只留下這一層自己的內容
        guard let own = li.copy() as? Element else {
            throw GraduationError.invalidResponse
        }
        try own.children()
            .filter { $0.tagName() == "ul" }
            .forEach { try $0.remove() }

        let text = try own.text()

        // 「已通過學分數：12」；資訊列則是「（已通過35學分）」
        let earned = number(after: "已通過學分數", in: text) ?? passedCredits(in: text)

        return CreditItem(
            name: name(from: text),
            status: try status(of: own),
            required:        number(after: "需通過學分數", in: text),
            earned:          earned,
            requiredCourses: number(after: "需通過課程數", in: text),
            passedCourses:   number(after: "已通過課程數", in: text),
            children: try childUL.map { try parseList($0) } ?? []
        )
    }

    // MARK: - 名稱：取全形括號「（」之前的文字
    private static func name(from text: String) -> String {
        let raw = text.components(separatedBy: "（").first ?? text
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 狀態：看第一個 <i> 圖示的 class
    // fa-check-circle → 通過、fa-square-check → 修習後通過、fa-times-circle → 未通過、fa-info-circle → 資訊
    private static func status(of element: Element) throws -> CreditItem.Status {
        guard let icon = try element.select("i").first() else {
            return .unknown
        }
        let cls = (try icon.className()).lowercased()

        if cls.contains("times") || cls.contains("xmark") { return .failed }
        if cls.contains("square")                         { return .conditional }
        if cls.contains("check")                          { return .passed }
        if cls.contains("info")                           { return .info }
        return .unknown
    }

    // MARK: - 抓「標籤：數字」，例如「需通過學分數：12」
    private static func number(after label: String, in text: String) -> Int? {
        let pattern = "\(label)[：:]\\s*\\d+"
        guard let range = text.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        return Int(text[range].filter(\.isNumber))
    }

    // MARK: - 抓「已通過35學分」
    private static func passedCredits(in text: String) -> Int? {
        guard let range = text.range(of: "已通過\\s*\\d+\\s*學分", options: .regularExpression) else {
            return nil
        }
        return Int(text[range].filter(\.isNumber))
    }

    // MARK: - 其他課規外修習課程（Kendo Grid 內嵌 JSON）
    // script 長這樣：jQuery("#OtherStudiesGrid").kendoGrid({ ... "data":{"Data":[...],"Total":7} ... })
    private static func parseOtherCourses(html: String) -> [OtherCourse] {
        guard let json = extractKendoData(from: html, gridId: "OtherStudiesGrid") else {
            print("其他課規外：找不到 Grid 資料")
            return []
        }
        do {
            let response = try JSONDecoder().decode(KendoGridResponse<OtherCourse>.self, from: json)
            return response.data
        } catch {
            print("其他課規外：JSON 解碼失敗 \(error)")
            return []
        }
    }

    /// 從 HTML 中取出指定 Kendo Grid 的 `"data":{...}` 物件（用大括號配對，會略過字串內的括號）
    private static func extractKendoData(from html: String, gridId: String) -> Data? {
        guard let gridRange = html.range(of: "\"#\(gridId)\"") else { return nil }

        let marker = "\"data\":{\"Data\":"
        guard let keyRange = html.range(of: marker, range: gridRange.upperBound..<html.endIndex) else {
            return nil
        }

        // 從 "data": 後面的 { 開始
        let objectStart = html.index(keyRange.lowerBound, offsetBy: "\"data\":".count)
        let bytes = Array(html.utf8[objectStart...])

        let quote     = UInt8(ascii: "\"")
        let backslash = UInt8(ascii: "\\")
        let open      = UInt8(ascii: "{")
        let close     = UInt8(ascii: "}")

        var depth = 0
        var inString = false
        var escaped = false

        for (i, byte) in bytes.enumerated() {
            if inString {
                if escaped {
                    escaped = false
                } else if byte == backslash {
                    escaped = true
                } else if byte == quote {
                    inString = false
                }
                continue
            }

            switch byte {
            case quote:
                inString = true
            case open:
                depth += 1
            case close:
                depth -= 1
                if depth == 0 {
                    return Data(bytes[0...i])
                }
            default:
                break
            }
        }
        return nil
    }

    // MARK: - 校定英語畢業門檻
    // <label id="langStatus"><span class="text-success">審查通過</span></label>
    private static func parseEnglishThreshold(in doc: Document) throws -> EnglishThreshold? {
        guard let label = try doc.select("#langStatus").first() else { return nil }

        let text = try label.text().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let isPassed = try !label.select(".text-success").isEmpty() || text.contains("通過") && !text.contains("未通過")
        return EnglishThreshold(resultText: text, isPassed: isPassed)
    }
}
