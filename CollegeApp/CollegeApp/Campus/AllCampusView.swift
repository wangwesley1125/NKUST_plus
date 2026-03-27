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

// 各校區訂一個座標（校門口）
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

// 搜尋教室結構
struct RoomResult: Identifiable {
    let id = UUID()
    let campus: Campus
    let building: Building
    let buildingName: String
    let floor: String
    let room: String
    let coordinate: CLLocationCoordinate2D
    let buildingColor: Color
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
    
    @State private var searchText = ""
    @State private var searchResults: [RoomResult] = []
    
    // 當在搜尋的 List 中選到教室就會關閉浮標
    @FocusState private var isSearchFocused: Bool
    
    // 選到的教室會跳出那棟大樓的 Sheet 同時讓剛剛搜尋的教室顯示亮色方便使用者知道
    @State private var highlightedRoom: String = ""

    // 之後可把各校區 buildings 合併進來，加上 campus 欄位
    var buildings: [Building] {
        switch selectedCampus {
        case .jiangong: return JiangongBuildings.all
        case .diyi:     return DiyiBuildings.all
        case .yanchao: return YanchaoBuildings.all
        case .qijin: return QijinBuildings.all
        case .nanzi: return NanziBuildings.all
        }
    }
    
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                
                    
                TextField("\(Image(systemName: "magnifyingglass")) 搜尋教室，例如：資001", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .focused($isSearchFocused)
                    .submitLabel(.done)
                    
                    .onSubmit {
                        isSearchFocused = false
                    }
                    .onChange(of: searchText) {
                        searchResults = performSearch(searchText)
                    }
                
                
                if !searchResults.isEmpty {
                    List(searchResults) { result in
                        Button {
                            selectedCampus = result.campus
                            withAnimation {
                                position = .region(MKCoordinateRegion(
                                    center: result.coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 0.0001, longitudeDelta: 0.0001)
                                ))
                            }
                            highlightedRoom = result.room
                            selectedBuilding = result.building
                            searchText = ""
                            searchResults = []
                            isSearchFocused = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.room)
                                        .font(.subheadline.bold())
                                    Text("\(result.campus.rawValue)校區・\(result.buildingName)・\(result.floor)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "location.fill")
                                    .foregroundStyle(result.buildingColor)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                    .listStyle(.plain)
                    .frame(maxHeight: 250)
                }
                
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
                    BuildingDetailSheet(building: building, highlightedRoom: highlightedRoom)
                }
                .onAppear {
                    locationManager.requestWhenInUseAuthorization()
                }
            }
            .navigationTitle("校園地圖")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - 搜尋函式
    func performSearch(_ query: String) -> [RoomResult] {
        guard !query.isEmpty else { return [] }
        var results: [RoomResult] = []
        
        for campus in Campus.allCases {
            let campusBuildings: [Building] = {
                switch campus {
                case .jiangong: return JiangongBuildings.all
                case .diyi:     return DiyiBuildings.all
                case .yanchao:  return YanchaoBuildings.all
                case .qijin:    return QijinBuildings.all
                case .nanzi:    return NanziBuildings.all
                }
            }()
            
            for building in campusBuildings {
                for floor in building.classrooms {
                    for room in floor.rooms {
                        if room.localizedCaseInsensitiveContains(query) {
                            results.append(RoomResult(
                                campus: campus,
                                building: building,
                                buildingName: building.name,
                                floor: floor.floor,
                                room: room,
                                coordinate: building.coordinate,
                                buildingColor: building.color
                            ))
                        }
                    }
                }
            }
        }
        return results
    }
}

#Preview {
    AllCampusView()
}
