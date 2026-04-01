//
//  CourseStorage.swift
//  CollegeApp
//
//  Created by Wesley Wang on 2026/4/1.
//

import Foundation

struct CourseCodable: Codable {
    let name: String
    let teacher: String
    let room: String
    let period: String
    let weekday: Int
}

class CourseStorage {
    static let shared = CourseStorage()
    
    private let appGroupID = "group.com.wesleywang.CollegeApp"
    private let fileName = "courses.json"
    
    private var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
    }
    
    func save(courses: [CourseCodable]) {
        guard let url = fileURL,
              let data = try? JSONEncoder().encode(courses) else { return }
        try? data.write(to: url)
    }
    
    func load() -> [CourseCodable] {
        guard let url = fileURL else {
                print("❌ fileURL 是 nil，App Group ID 可能設定錯誤")
                return []
            }
            guard let data = try? Data(contentsOf: url) else {
                print("❌ 讀不到檔案，主 App 可能還沒存過資料")
                return []
            }
            guard let codable = try? JSONDecoder().decode([CourseCodable].self, from: data) else {
                print("❌ JSON 解析失敗")
                return []
            }
            print("✅ 讀到 \(codable.count) 堂課")
            return codable
    }
}
