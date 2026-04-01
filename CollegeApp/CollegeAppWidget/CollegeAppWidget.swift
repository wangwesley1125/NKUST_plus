//
//  CollegeAppWidget.swift
//  CollegeAppWidget
//
//  Created by 王耀偉 on 2026/4/1.
//

import WidgetKit
import SwiftUI

// MARK: - Entry（Widget 的資料容器）
struct CourseEntry: TimelineEntry {
    let date: Date
    let courses: [CourseCodable]
}

// MARK: - Provider
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> CourseEntry {
        CourseEntry(date: .now, courses: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (CourseEntry) -> Void) {
        let courses = CourseStorage.shared.load()
        completion(CourseEntry(date: .now, courses: courses))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CourseEntry>) -> Void) {
        let courses = CourseStorage.shared.load()
        let entry = CourseEntry(date: .now, courses: courses)
        // 每小時更新一次
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Widget 畫面（先簡單顯示今天課程）
struct CollegeAppWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var todayCourses: [CourseCodable] {
        let weekday = Calendar.current.component(.weekday, from: entry.date)
        let dayIndex = weekday == 1 ? 6 : weekday - 2
        return entry.courses.filter { $0.weekday == dayIndex }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // 標題
            HStack {
                Text("今日課表")
                    .font(.caption2)
                    .bold()
                    .foregroundColor(.teal)
                Spacer()
                Text(Date(), style: .date)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            Divider()

            if todayCourses.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text("今天沒有課 🎉")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                Spacer()
            } else {
                // small 最多顯示 4 堂，medium 顯示全部
                let limit = family == .systemSmall ? 4 : todayCourses.count
                
                ForEach(todayCourses.prefix(limit), id: \.period) { course in
                    HStack(spacing: 4) {
                        Text(course.period)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 16, height: 16)
                            .background(Color.teal)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        
                        Text(course.name)
                            .font(.system(size: family == .systemSmall ? 10 : 11, weight: .semibold))
                            .lineLimit(1)
                        
                        if family == .systemMedium {
                            Spacer()
                            Text(course.room)
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                
                // small 如果課程超過 4 堂，顯示還有幾堂
                if family == .systemSmall && todayCourses.count > 4 {
                    Text("還有 \(todayCourses.count - 4) 堂...")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Widget 設定
struct CollegeAppWidget: Widget {
    let kind: String = "CollegeAppWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CollegeAppWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("今日課表")
        .description("顯示今天的課程")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    CollegeAppWidget()
} timeline: {
    CourseEntry(date: .now, courses: [])
}

#Preview(as: .systemMedium) {
    CollegeAppWidget()
} timeline: {
    CourseEntry(date: .now, courses: [])
}
