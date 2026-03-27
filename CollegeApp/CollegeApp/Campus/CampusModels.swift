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
    
    var highlightedRoom: String = ""
    
    init(_ items: [String], highlightedRoom: String = "") {
        self.items = items
        self.highlightedRoom = highlightedRoom
    }
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 4)
    
    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(item == highlightedRoom ? Color.yellow : Color(.systemGray6))
                    .foregroundStyle(item == highlightedRoom ? Color.black : Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// 建築跳出的內容
struct BuildingDetailSheet: View {
    let building: Building
    
    // 選擇的樓層
    @State private var selectedFloor: String = ""
    
    // 點亮使用者搜尋的那間教室
    var highlightedRoom: String = ""
    
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
                        FlowLayout(current.rooms, highlightedRoom: highlightedRoom)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6).opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .layoutPriority(1)
                }
            }
            
            Spacer()
            
            // 開啟 Google Map 按鈕
            Button {
                let lat = building.coordinate.latitude
                let lng = building.coordinate.longitude
                let name = building.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                
                // 優先開啟 Google Maps app，沒安裝則用瀏覽器
                if let url = URL(string: "comgooglemaps://?q=\(name)&center=\(lat),\(lng)&zoom=18"),
                   UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                } else if let url = URL(string: "https://www.google.com/maps/search/?api=1&query=\(lat),\(lng)") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("在 Google Maps 開啟", systemImage: "map.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
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
            if !highlightedRoom.isEmpty,
               let matchedFloor = building.classrooms.first(where: { $0.rooms.contains(highlightedRoom) }) {
                selectedFloor = matchedFloor.floor  // 跳到高亮教室所在的樓層
            } else if let first = building.classrooms.first {
                selectedFloor = first.floor
            }
        }
    }
}
