//
//  GraduationParser.swift
//  CollegeApp
//
//  Created by Wesley on 2026/10/1.
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
        return result
    }
 
    // MARK: - 找到標題所在區塊，回傳底下第一層清單
    private static func section(titled title: String, in doc: Document) throws -> [CreditItem] {
        // 找到「自己的文字」含有標題的元素（例如 <legend>）
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
 
        return CreditItem(
            name: name(from: text),
            status: try status(of: own),
            required:        number(after: "需通過學分數", in: text),
            earned:          number(after: "已通過學分數", in: text),
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
 
    // MARK: - 狀態：看第一個圖示元素的 class / 內容
    // 請到 DevTools → Elements 確認實際的圖示寫法，必要時調整關鍵字
    private static func status(of element: Element) throws -> CreditItem.Status {
        guard let icon = try element.select("i, svg, img, span[class*=icon], span[class*=fa]").first() else {
            return .unknown
        }
        let marker = (try icon.outerHtml()).lowercased()
 
        if marker.contains("times") || marker.contains("xmark")
            || marker.contains("x-circle") || marker.contains("danger") || marker.contains("red") {
            return .failed
        }
        if marker.contains("square") || marker.contains("warning") || marker.contains("orange") {
            return .conditional
        }
        if marker.contains("check") {
            return .passed
        }
        return .unknown
    }
 
    // MARK: - 抓「標籤：數字」
    // 例如「需通過學分數：12」或「需通過學分數： 12」
    private static func number(after label: String, in text: String) -> Int? {
        let pattern = "\(label)[：:]\\s*\\d+"
        guard let range = text.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        return Int(text[range].filter(\.isNumber))
    }
}
