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

// 教室標籤
struct FlowLayout: View {
    let items: [String]
    
    init(_ items: [String]) {
        self.items = items
    }
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 4)
    
    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// 建築跳出的內容
struct BuildingDetailSheet: View {
    let building: Building
    
    @State private var selectedFloor: String = ""
    
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
            
            if !building.classrooms.isEmpty {
                Divider()
                
                // 樓層選擇列
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(building.classrooms, id: \.floor) { row in
                            let isSelected = selectedFloor == row.floor
                            Button {
                                selectedFloor = row.floor
                            } label: {
                                Text(row.floor)
                                    .font(.subheadline.bold())
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(isSelected ? building.color : Color(.systemGray5))
                                    .foregroundStyle(isSelected ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 1)
                }
                
                // 選定樓層的教室
                if let current = building.classrooms.first(where: { $0.floor == selectedFloor }) {
                    Text("教室列表")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    ScrollView {
                        FlowLayout(current.rooms)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6).opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .layoutPriority(1)
                }
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
        .presentationContentInteraction(.scrolls)
        .onAppear {
            if let first = building.classrooms.first {
                selectedFloor = first.floor
            }
        }
    }
}
