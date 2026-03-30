//
//  WeekGreedView.swift
//  CollegeApp
//
//  Created by WesleyWang on 2026/3/30.
//

import SwiftUI

struct WeekGridView: View {
    let courses: [Course]
    
    let weekdays = ["一", "二", "三", "四", "五"]
    let columnWidth: CGFloat = 70
    let rowHeight: CGFloat = 70
    
    var body: some View {
        ScrollView([.vertical]) {
            VStack(spacing: 0) {
                // 表頭：節次欄 + 週一到週五
                HStack(spacing: 0) {
                    // 左上角空白
                    Text("")
                        .frame(width: 36, height: 36)
                    
                    ForEach(0..<5, id: \.self) { i in
                        Text(weekdays[i])
                            .font(.caption)
                            .bold()
                            .frame(width: columnWidth, height: 36)
                            //.background(Color(.systemGray6))
                    }
                }
                
                //Divider()
                
                // 每一節
                ForEach(CourseParser.periods, id: \.self) { period in
                    HStack(spacing: 0) {
                        // 左側節次
                        VStack(spacing: 2) {
                            if let time = CourseParser.periodTimes[period] {
                                Text(time.0).font(.system(size: 10))
                                Text(period)
                                    .font(.caption2)
                                    .bold()
                                    .foregroundStyle(.tint)
                                Text(time.1).font(.system(size: 10))
                            }
                        }
                        .frame(width: 36, height: rowHeight)
                        //.background(Color(.systemGray6))
                        
                        // 週一到週五的格子
                        ForEach(0..<5, id: \.self) { dayIndex in
                            GridCell(
                                course: courses.first {
                                    $0.weekday == dayIndex && $0.period == period
                                }
                            )
                            .frame(width: columnWidth, height: rowHeight)
                        }
                    }
                    
                    //Divider()
                }
            }
        }
    }
}

// MARK: - 格子
struct GridCell: View {
    let course: Course?
    @State private var showDetail = false
    
    var body: some View {
        Button {
            if course != nil { showDetail = true }
        } label: {
            ZStack {
                // 背景
                RoundedRectangle(cornerRadius: 8)
                    .fill(course != nil ? Color.teal.opacity(0.85) : Color(.systemGray3).opacity(0.3))
                    .padding(3)
                
                if let c = course {
                    VStack(spacing: 2) {
                        Text(c.name)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                        Text(c.room)
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                    .padding(4)
                }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            if let c = course {
                CourseDetailSheet(course: c)
            }
        }
    }
}

// MARK: - 課程詳細 Sheet
struct CourseDetailSheet: View {
    let course: Course
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    detailRow(icon: "book.fill", label: "課程", value: course.name)
                    detailRow(icon: "person.fill", label: "老師", value: course.teacher)
                    detailRow(icon: "mappin.circle.fill", label: "教室", value: course.room)
                    detailRow(icon: "clock.fill", label: "節次", value: course.period)
                }
            }
            .navigationTitle(course.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
    }
    
    func detailRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.teal)
                .frame(width: 24)
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .bold()
        }
    }
}

#Preview {
    WeekGridView(courses: [])
}
