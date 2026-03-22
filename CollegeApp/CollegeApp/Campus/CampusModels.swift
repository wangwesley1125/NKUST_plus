//
//  CampusModels.swift
//  CollegeApp
//
//  Created by Wesley Wang on 2026/3/22.
//

import SwiftUI
import MapKit
import CoreLocation


// 建築資料結構
struct Building: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let description: String
    let icon: String
    let color: Color
    let classrooms: [(floor: String, rooms: [String])]
    
    // 讓沒有教室資料的建築不用每次都填
    init(name: String, coordinate: CLLocationCoordinate2D,
             description: String, icon: String, color: Color,
             classrooms: [(floor: String, rooms: [String])] = []) {
        self.name = name
        self.coordinate = coordinate
        self.description = description
        self.icon = icon
        self.color = color
        self.classrooms = classrooms
    }
}

// 教室表格
struct FlowLayout: View {
    let items: [String]
    
    init(_ items: [String]) {
        self.items = items
    }
    
    var body: some View {
        
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 0)], alignment: .leading, spacing: 4) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }
}

// 建築跳出的內容
struct BuildingDetailSheet: View {
    let building: Building
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 標題
            HStack {
                Image(systemName: building.icon)
                    .foregroundStyle(building.color)
                    .font(.title2)
                Text(building.name)
                    .font(.title2.bold())
            }
            
            if !building.description.isEmpty {
                Text(building.description)
                    .foregroundStyle(.secondary)
            }
            
            // 有教室資料才顯示表格
            if !building.classrooms.isEmpty {
                Divider()
                Text("教室列表")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                
                ScrollView {
                    VStack(spacing: 0) {
                        // 表頭
                        HStack(spacing: 0) {
                            Text("樓層")
                                .frame(width: 50)
                                .padding(.vertical, 6)
                            Divider().frame(height: 30)
                            Text("教室編號")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .font(.caption.bold())
                        .background(building.color.opacity(0.15))
                        
                        Divider()
                        
                        // 每一行
                        ForEach(building.classrooms, id: \.floor) { row in
                            HStack(alignment: .center, spacing: 0) {
                                Text(row.floor)
                                    .frame(width: 50)
                                    .padding(.vertical, 6)
                                Divider()
                                // 教室們自動換行
                                FlowLayout(row.rooms)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 6)
                            }
                            .font(.caption)
                            
                            Divider()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3))
                    )
                }
                .layoutPriority(1)
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents(
            building.classrooms.isEmpty
            ? [.height(110)]
            : [.height(400)]
        )
        // 讓內層 ScrollView 優先處理滾動，不被 sheet 手勢攔截
        .presentationContentInteraction(.scrolls)
    }
}
