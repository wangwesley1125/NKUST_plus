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

class ProfileParser {
    static func parse(html: String) throws -> StudentProfile {
        let doc = try SwiftSoup.parse(html)
        var profile = StudentProfile()
        
        let fields = try doc.select(".fielddata")
        let texts = try fields.map { try $0.text() }
        
        if texts.count > 0 { profile.name = texts[0] }
        if texts.count > 1 { profile.englishName = texts[1] }
        if texts.count > 2 { profile.department = texts[3] }
        if texts.count > 4 { profile.className = texts[4] }
        if texts.count > 5 { profile.studentId = texts[5] }
        if texts.count > 11 { profile.status = texts[11] }
        
        // 照片 URL
        if let img = try doc.select("img.photo").first() {
            let src = try img.attr("src")
            profile.photoURL = "https://stdsys.nkust.edu.tw\(src)"
        }
        
        return profile
    }
}
