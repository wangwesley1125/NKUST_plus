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
        GeometryReader { geo in
            let availableWidth = geo.size.width - 36  // 扣掉左側節次欄
            let colWidth = availableWidth / 5         // 平均分給五天

            ScrollView([.vertical]) {
                VStack(spacing: 0) {
                    // 表頭
                    HStack(spacing: 0) {
                        Text("")
                            .frame(width: 36, height: 36)
                        
                        ForEach(0..<5, id: \.self) { i in
                            Text(weekdays[i])
                                .font(.caption)
                                .bold()
                                .frame(width: colWidth, height: 36)
                        }
                    }
                    
                    // 每一節
                    ForEach(CourseParser.periods, id: \.self) { period in
                        HStack(spacing: 0) {
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
                            
                            ForEach(0..<5, id: \.self) { dayIndex in
                                GridCell(
                                    course: courses.first {
                                        $0.weekday == dayIndex && $0.period == period
                                    }
                                )
                                .frame(width: colWidth, height: rowHeight)
                            }
                        }
                    }
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
                        .fill(
                            course.map { courseColor(for: $0.name).opacity(0.85) }
                            ?? Color(.systemGray3).opacity(0.3)
                        )
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
    
    // 課程顯示不同顏色
    func courseColor(for name: String) -> Color {
        let colors: [Color] = [
            .teal, .blue, .indigo, .purple, .pink,
                .orange, .mint, .cyan, .green,
                Color(red: 0.4, green: 0.6, blue: 1.0),   // 淡藍紫
                Color(red: 1.0, green: 0.6, blue: 0.2),   // 暖橘
                Color(red: 0.4, green: 0.8, blue: 0.6)    // 薄荷綠
        ]
        let hash = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return colors[hash % colors.count]
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
