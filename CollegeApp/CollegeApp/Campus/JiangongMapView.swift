//
//  CampusMapView.swift
//  CollegeApp
//
//  Created by Wesley Wang on 2026/3/14.
//

import SwiftUI
import MapKit

// 建築資料結構
struct Building: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let description: String
    let icon: String
    let color: Color
}

struct JiangongMapView: View {
    
    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 22.651611327466625, longitude: 120.32885345739281),
            span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
        )
    )
    
    @State private var selectedBuilding: Building?
    
    // 邊界範圍
    // 左上：22.651475, 120.327463
    // 右上：22.651787, 120.329255
    // 左下：22.646656, 120.327553
    // 右下：22.646687, 120.329445
    let minLat = 22.646656
    let maxLat = 22.651787
    let minLng = 120.327463
    let maxLng = 120.329445
    
    // 校園建築
    let buildings: [Building] = [
        Building(name: "正門",
                 coordinate: CLLocationCoordinate2D(latitude: 22.651919, longitude: 120.328684),
                 description: "",
                icon: "door.french.open",
                 color: .teal),
        Building(name: "機車棚",
                 coordinate: CLLocationCoordinate2D(latitude: 22.651596922203588, longitude: 120.32908811277623),
                 description: "東區機車棚",
                 icon: "motorcycle",
                  color: Color.pink),
        Building(name: "機車棚",
                 coordinate: CLLocationCoordinate2D(latitude: 22.651248, longitude: 120.327595),
                 description: "西區機車棚",
                 icon: "motorcycle",
                  color: Color.pink),
        Building(name: "汽車停車場",
                 coordinate: CLLocationCoordinate2D(latitude: 22.650755, longitude: 120.327793),
                 description: "",
                 icon: "car",
                  color: Color.pink),
        Building(name: "行政大樓",
                 coordinate: CLLocationCoordinate2D(latitude: 22.651327, longitude: 120.328770),
                 description: "",
                 icon: "building",
                  color: Color.blue),
        Building(name: "育賢樓",
                 coordinate: CLLocationCoordinate2D(latitude: 22.650496705338718, longitude: 120.32777429929709),
                 description: "",
                 icon: "building",
                  color: Color.orange),
        Building(name: "圖書館",
                 coordinate: CLLocationCoordinate2D(latitude: 22.650189621341763, longitude: 120.32779032327883),
                 description: "",
                 icon: "book",
                  color: Color.blue),
        Building(name: "資訊工業大樓",
                 coordinate: CLLocationCoordinate2D(latitude: 22.650131760283124, longitude: 120.32768804576807),
                 description: "",
                 icon: "building",
                  color: Color.gray),
        Building(name: "咖啡廣場",
                 coordinate: CLLocationCoordinate2D(latitude: 22.650119, longitude: 120.328045),
                 description: "",
                 icon: "cup.and.heat.waves",
                  color: Color.brown),
        Building(name: "學生餐廳",
                 coordinate: CLLocationCoordinate2D(latitude: 22.649723, longitude: 120.327710),
                 description: "",
                 icon: "fork.knife",
                  color: Color.orange),
        Building(name: "學生活動中心",
                 coordinate: CLLocationCoordinate2D(latitude: 22.649929, longitude: 120.327944),
                 description: "",
                 icon: "figure.badminton",
                  color: Color.orange),
        Building(name: "ATM",
                 coordinate: CLLocationCoordinate2D(latitude: 22.649769, longitude: 120.327980),
                 description: "",
                 icon: "dollarsign.bank.building",
                  color: Color.green),
        Building(name: "教學大樓",
                 coordinate: CLLocationCoordinate2D(latitude: 22.650743, longitude: 120.328742),
                 description: "",
                 icon: "building",
                  color: Color.blue),
        Building(name: "西棟",
                 coordinate: CLLocationCoordinate2D(latitude: 22.650581872973152, longitude: 120.32833808217707),
                 description: "",
                 icon: "building",
                  color: Color.blue),
        Building(name: "東棟",
                 coordinate: CLLocationCoordinate2D(latitude: 22.650566872946502, longitude: 120.32920356354421),
                 description: "",
                 icon: "building",
                  color: Color.blue),
        Building(name: "萊爾富",
                 coordinate: CLLocationCoordinate2D(latitude: 22.649755037673355, longitude: 120.32901559874364),
                 description: "",
                 icon: "storefront",
                  color: Color.green),
        Building(name: "電機工程系",
                 coordinate: CLLocationCoordinate2D(latitude: 22.64947532320891, longitude: 120.32855157660838),
                 description: "",
                 icon: "building",
                  color: Color.gray),
        Building(name: "模具系",
                 coordinate: CLLocationCoordinate2D(latitude: 22.64947532320891, longitude: 120.32913250623187),
                 description: "",
                 icon: "building",
                  color: Color.gray),
        Building(name: "土木工程系",
                 coordinate: CLLocationCoordinate2D(latitude: 22.648918902987248, longitude: 120.32911384274722),
                 description: "",
                 icon: "building",
                  color: Color.gray),
        Building(name: "機械工程系",
                 coordinate: CLLocationCoordinate2D(latitude: 22.648282093812334, longitude: 120.3291390157567),
                 description: "",
                 icon: "building",
                  color: Color.gray),
        Building(name: "中正堂",
                 coordinate: CLLocationCoordinate2D(latitude: 22.64928426315465, longitude: 120.32790094610567),
                 description: "",
                 icon: "building",
                  color: Color.gray),
        Building(name: "化工系",
                 coordinate: CLLocationCoordinate2D(latitude: 22.64897979412971, longitude: 120.32770782706619),
                 description: "",
                 icon: "building",
                  color: Color.gray),
        Building(name: "司令台",
                 coordinate: CLLocationCoordinate2D(latitude: 22.648251466414806, longitude: 120.32783600364664),
                 description: "",
                 icon: "megaphone.fill",
                  color: Color.gray),
        Building(name: "排球場",
                 coordinate: CLLocationCoordinate2D(latitude: 22.647762603314884, longitude: 120.32913901575833),
                 description: "",
                 icon: "figure.volleyball",
                  color: Color.yellow),
        Building(name: "網球場",
                 coordinate: CLLocationCoordinate2D(latitude: 22.647426513573453, longitude: 120.32915235114201),
                 description: "",
                 icon: "tennisball.fill",
                  color: Color.green),
        Building(name: "游泳池",
                 coordinate: CLLocationCoordinate2D(latitude: 22.647245178534902, longitude: 120.32880030348547),
                 description: "",
                 icon: "figure.open.water.swim",
                  color: Color.blue),
        Building(name: "慧樓(女宿)",
                 coordinate: CLLocationCoordinate2D(latitude: 22.647255961421443, longitude: 120.32863679429775),
                 description: "",
                 icon: "bed.double",
                  color: Color.pink),
        Building(name: "影印&訂書",
                 coordinate: CLLocationCoordinate2D(latitude: 22.647225545673837, longitude: 120.32827403825472),
                 description: "",
                 icon: "printer",
                  color: Color.gray),
        Building(name: "男宿舍",
                 coordinate: CLLocationCoordinate2D(latitude: 22.646826662914165, longitude: 120.328746),
                 description: "",
                 icon: "bed.double",
                  color: Color.blue),
        Building(name: "後門",
                 coordinate: CLLocationCoordinate2D(latitude: 22.64674497470727, longitude: 120.32930942294551),
                 description: "",
                 icon: "door.french.open",
                  color: .teal),
    ]
    
    var body: some View {
        Map(position: $position){
            
            // 使用者當前位置
            UserAnnotation()
            
            // 建築標記
            ForEach(buildings) { building in
                Annotation(building.name, coordinate: building.coordinate) {
                    Button {
                        selectedBuilding = building
                    } label: {
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
        .mapStyle(.standard(
            elevation: .realistic,
            pointsOfInterest: .excludingAll  // 移除所有預設標記
        ))
        .mapControls {
            MapUserLocationButton() // 回到使用者位置按鈕
        }
//        .onMapCameraChange(frequency: .onEnd) { context in
//            let center = context.region.center
//            var lat = center.latitude
//            var lng = center.longitude
//            
//            // 超出範圍就夾回邊界內
//            lat = min(max(lat, minLat), maxLat)
//            lng = min(max(lng, minLng), maxLng)
//            
//            // 只有真的超出才更新，避免無限觸發
//            if lat != center.latitude || lng != center.longitude {
//                withAnimation(.spring(duration: 0.3)) {
//                    position = .region(MKCoordinateRegion(
//                        center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
//                        span: context.region.span
//                    ))
//                }
//            }
//        }
//        .overlay(alignment: .bottomTrailing) {
//            VStack(spacing: 8) {
//                // 回到校園中心
//                Button {
//                    withAnimation {
//                        position = .region(MKCoordinateRegion(
//                            center: CLLocationCoordinate2D(latitude: 22.651611, longitude: 120.328853),
//                            span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
//                        ))
//                    }
//                } label: {
//                    Image(systemName: "building.columns")
//                        .padding(12)
//                        .background(.thinMaterial)
//                        .clipShape(Circle())
//                        .shadow(radius: 2)
//                }
//                
//                // 回到使用者位置（不受校園範圍限制）
//                MapUserLocationButton()
//            }
//            .padding()
//        }
        // 點擊建築顯示資訊
        .sheet(item: $selectedBuilding) { building in
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: building.icon)
                        .foregroundStyle(building.color)
                        .font(.title2)
                    Text(building.name)
                        .font(.title2.bold())
                }
                Text(building.description)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .presentationDetents([.height(200)])
        }
    }
}

#Preview {
    JiangongMapView()
}
