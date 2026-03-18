//
//  CourseParser.swift
//  CollegeApp
//
//  Created by 王耀偉 on 2026/3/12.
//

import Foundation
import SwiftSoup

struct Course: Identifiable {
    let id = UUID()
    let name: String
    let teacher: String
    let room: String
    let period: String
    let weekday: Int  // 0=週一 ... 6=週日
}

class CourseParser {
    static let periods = [
        "M","1","2","3","4","A","5","6","7","8","9","10","11","12","13"
    ]
    
    static let periodTimes: [String: (String, String)] = [
        "M":("07:10","08:00"), "1":("08:10","09:00"), "2":("09:10","10:00"),
        "3":("10:10","11:00"), "4":("11:10","12:00"), "A":("12:10","13:00"),
        "5":("13:30","14:20"), "6":("14:30","15:20"), "7":("15:30","16:20"),
        "8":("16:30","17:20"), "9":("17:30","18:20"), "10":("18:30","19:20"),
        "11":("19:25","20:15"), "12":("20:20","21:10"), "13":("21:15","22:05")
    ]
    
    static func parse(html: String) throws -> [Course] {
        let doc = try SwiftSoup.parse(html)
        var courses: [Course] = []
        
        let rows = try doc.select("#detail-table tbody tr")
        
        for (rowIndex, row) in rows.enumerated() {
            guard rowIndex < periods.count else { break }
            let period = periods[rowIndex]
            
            let cells = try row.select("td")
            guard cells.size() == 8 else { continue }
            
            for weekday in 0..<7 {
                let cell = cells.get(weekday + 1)
                guard let link = try? cell.select("a").first(),
                      !((try? link.text()) ?? "").isEmpty else { continue }
                
                let courseName = (try? link.text()) ?? ""
                let cellText = (try? cell.text()) ?? ""
                
                // cellText 格式：「課名 老師 教室」
                var parts = cellText.components(separatedBy: " ").filter { !$0.isEmpty }
                // 移掉課名（可能含空白）
                let nameWords = courseName.components(separatedBy: " ").count
                parts.removeFirst(min(nameWords, parts.count))
                
                let teacher = parts.count > 0 ? parts[0] : ""
                let room = parts.count > 1 ? parts[1] : ""
                
                courses.append(Course(
                    name: courseName,
                    teacher: teacher,
                    room: room,
                    period: period,
                    weekday: weekday
                ))
            }
        }
        
        return courses
    }
}
