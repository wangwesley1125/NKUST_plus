//
//  AllCampus.swift
//  CollegeApp
//
//  Created by Wesley Wang on 2026/3/15.
//

import SwiftUI
import MapKit
import CoreLocation

enum Campus: String, CaseIterable {
    case jiangong = "建工"
    case yanchao  = "燕巢"
    case diyi     = "第一"
    case qijin    = "旗津"
    case nanzi    = "楠梓"
}

// 各校區中心座標
extension Campus {
    var center: CLLocationCoordinate2D {
        switch self {
        case .jiangong: return CLLocationCoordinate2D(latitude: 22.651611, longitude: 120.328853)
        case .yanchao:  return CLLocationCoordinate2D(latitude: 22.772465, longitude: 120.400284)
        case .diyi:     return CLLocationCoordinate2D(latitude: 22.751928, longitude: 120.331460)
        case .qijin:    return CLLocationCoordinate2D(latitude: 22.608805, longitude: 120.271993)
        case .nanzi:    return CLLocationCoordinate2D(latitude: 22.724602, longitude: 120.314650)
        }
    }
}

// 教室表格
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
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .presentationDetents(
            building.classrooms.isEmpty
            ? [.height(110)]
            : [.height(250)]
        )
    }
}

struct AllCampusView: View {
    @State private var selectedCampus: Campus = .jiangong
    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 22.651611, longitude: 120.328853),
            span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
        )
    )
    @State private var selectedBuilding: Building?
    
    @State private var locationManager = CLLocationManager()

    // 之後可把各校區 buildings 合併進來，加上 campus 欄位
    let buildings = JiangongBuildings.all as [Building]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 校區選擇列
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Campus.allCases, id: \.self) { campus in
                            Button {
                                withAnimation(.spring(duration: 0.4)) {
                                    selectedCampus = campus
                                    position = .region(MKCoordinateRegion(
                                        center: campus.center,
                                        span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
                                    ))
                                }
                            } label: {
                                Text(campus.rawValue)
                                    .font(.subheadline).bold()
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(selectedCampus == campus ? Color.teal : Color(.systemGray5))
                                    .foregroundColor(selectedCampus == campus ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }

                Divider()

                // 單一地圖
                Map(position: $position) {
                    
                    UserAnnotation()
                    
                    ForEach(buildings) { building in
                        Annotation(building.name, coordinate: building.coordinate) {
                            Button { selectedBuilding = building } label: {
                                Image(systemName: building.icon)
                                    .font(.title3)
                                    .foregroundStyle(.white)
                                    .padding(8)
                                    .background(building.color)
                                    .clipShape(Circle())
                                    .shadow(radius: 2)
                            }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
                .mapControls {
                    MapUserLocationButton()
                }
                .sheet(item: $selectedBuilding) { building in
                    BuildingDetailSheet(building: building)
                }
                .onAppear {
                    locationManager.requestWhenInUseAuthorization()
                }
            }
            .navigationTitle("校園地圖")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    AllCampusView()
}
