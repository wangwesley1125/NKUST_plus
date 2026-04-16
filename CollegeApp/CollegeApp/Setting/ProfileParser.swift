//
//  ProfileParser.swift
//  CollegeApp
//
//  Created by Wesley Wang on 2026/3/17.
//

import Foundation
import SwiftSoup

struct StudentProfile {
    var name: String = ""
    var englishName: String = ""
    var studentId: String = ""
    var department: String = ""
    var className: String = ""
    var status: String = ""
    var photoURL: String = ""
}

// MARK: - 學校舊版
//class ProfileParser {
//    static func parse(html: String) throws -> StudentProfile {
//        let doc = try SwiftSoup.parse(html)
//        var profile = StudentProfile()
//        
//        let fields = try doc.select(".fielddata")
//        let texts = try fields.map { try $0.text() }
//        
//        if texts.count > 0 { profile.name = texts[0] }
//        if texts.count > 1 { profile.englishName = texts[1] }
//        if texts.count > 2 { profile.department = texts[2] }
//        if texts.count > 4 { profile.className = texts[4] }
//        if texts.count > 5 { profile.studentId = texts[5] }
//        if texts.count > 11 { profile.status = texts[11] }
//        
//        // 照片 URL
//        if let img = try doc.select("img.photo").first() {
//            let src = try img.attr("src")
//            profile.photoURL = "https://stdsys.nkust.edu.tw\(src)"
//        }
//        
//        return profile
//    }
//}

// 根據新的 HTML 結構，index 對應如下：
// 0: 姓名, 1: 英文姓名, 2: 學制, 3: 科系
// 4: 班級, 5: 學號, 6: 出生日期, 7: 性別
// 8: 自我性別認同, 9: 服役記錄, 10: 身份證號, 11: 在學狀態
// 12: 入學前學歷, 13: 族語能力, 14: 家長姓名, 15: 與家長關係
// 16: 聯絡電話, 17: 戶籍地址, 18: 通訊地址

class ProfileParser {
    // 方法一: 利用 index 對應
//    static func parse(html: String) throws -> StudentProfile {
//        let doc = try SwiftSoup.parse(html)
//        var profile = StudentProfile()
//        
//        let values = try doc.select(".info-value")
//        let texts = try values.map { try $0.text() }
//        
          
//
//        if texts.count > 0  { profile.name = texts[0] }
//        if texts.count > 1  { profile.englishName = texts[1] }
//        if texts.count > 3  { profile.department = texts[3] }
//        if texts.count > 4  { profile.className = texts[4] }
//        if texts.count > 5  { profile.studentId = texts[5] }
//        if texts.count > 11 { profile.status = texts[11] }
//        
//        // 照片 URL（class 也改了，從 img.photo 改成 img.student-photo）
//        if let img = try doc.select("img.student-photo").first() {
//            let src = try img.attr("src")
//            profile.photoURL = "https://stdsys.nkust.edu.tw\(src)"
//        }
//        
//        return profile
//    }
    
    // 方法二: 用 label 來找 value
    static func parse(html: String) throws -> StudentProfile {
        let doc = try SwiftSoup.parse(html)
        var profile = StudentProfile()
        
        let items = try doc.select(".info-item")
        
        for item in items {
            let label = try item.select(".info-label").text()
            let value = try item.select(".info-value").text()
            
            switch label {
            case "姓名":        profile.name = value
            case "英文姓名":    profile.englishName = value
            case "學號":        profile.studentId = value
            case "科系":        profile.department = value
            case "班級":        profile.className = value
            case "在學狀態":    profile.status = value
            default: break
            }
        }
        
        // 照片
        if let img = try doc.select("img.student-photo").first() {
            let src = try img.attr("src")
            profile.photoURL = "https://stdsys.nkust.edu.tw\(src)"
        }
        
        return profile
    }
}


