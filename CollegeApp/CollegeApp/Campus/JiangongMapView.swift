//
//  CampusMapView.swift
//  CollegeApp
//
//  Created by Wesley Wang on 2026/3/14.
//

import SwiftUI
import MapKit

enum JiangongBuildings {
    static let all: [Building] = [
        Building(name: "正門",
                 coordinate: CLLocationCoordinate2D(latitude: 22.651919, longitude: 120.328684),
                 description: "建工校區正門口",
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
                  color: Color.blue,
                 classrooms: [
                    (floor: "4F", rooms: ["行401", "行402", "行403", "行404", "行405多功能研習", "行406", "行407", "行408", "行409", "行410"]),
                     (floor: "5F", rooms: ["行501", "行502", "行503", "行504", "行505AI", "行506", "行507", "行508", "行509", "行510", "行511"])
                 ]),
        Building(name: "育賢樓",
                 coordinate: CLLocationCoordinate2D(latitude: 22.650496705338718, longitude: 120.32777429929709),
                 description: "",
                 icon: "building",
                  color: Color.orange,
                 classrooms: [
                     (floor: "1F", rooms: ["育101","育102","育103","育104","育105"]),
                     (floor: "2F", rooms: ["育201","育202","育203","育204","育205","育206"]),
                     (floor: "3F", rooms: ["育301","育302","育303","育304","育305"]),
                     (floor: "4F", rooms: ["育400","育401","育402","育403","育404","育405"]),
                     (floor: "5F", rooms: ["育500","育501","育502","育503","育505"]),
                 ]),
        Building(name: "圖書館",
                 coordinate: CLLocationCoordinate2D(latitude: 22.650189621341763, longitude: 120.32779032327883),
                 description: "",
                 icon: "book",
                  color: Color.blue,
                 classrooms: [
                     (floor: "1F", rooms: ["資訊工業大樓 1F"]),
                     (floor: "2F", rooms: ["資訊工業大樓 2F"]),
                     (floor: "3F", rooms: ["資訊工業大樓 3F"])
                 ]),
        Building(name: "資訊工業大樓",
                 coordinate: CLLocationCoordinate2D(latitude: 22.650131760283124, longitude: 120.32768804576807),
                 description: "",
                 icon: "building",
                  color: Color.gray,
                 classrooms: [
                     (floor: "B1F", rooms: ["資001","資002"]),
                     (floor: "4F", rooms: ["資401","資405","資406B"]),
                     (floor: "5F", rooms: ["資501A","資504"]),
                     (floor: "6F", rooms: ["資606"]),
                     (floor: "7F", rooms: ["資701","資704"]),
                     (floor: "8F", rooms: ["資805","資809","系辦"]),
                     (floor: "10F", rooms: ["光電所第一研討室","光電所第二研討室"]),
                     (floor: "12F", rooms: ["資1207"]),
                 ]),
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
                  color: Color.orange,
                 classrooms: [
                     (floor: "B1F", rooms: ["健身房", "桌球教室", "韻律教室"]),
                     (floor: "3F", rooms: ["活動中心 G302", "視聽教室", "羽球場"])
                 ]),
        Building(name: "ATM",
                 coordinate: CLLocationCoordinate2D(latitude: 22.649769, longitude: 120.327980),
                 description: "",
                 icon: "dollarsign.bank.building",
                  color: Color.green),
        Building(name: "教學大樓",
                 coordinate: CLLocationCoordinate2D(latitude: 22.650743, longitude: 120.328742),
                 description: "無資訊",
                 icon: "building",
                  color: Color.blue),
        Building(name: "西棟",
                 coordinate: CLLocationCoordinate2D(latitude: 22.650581872973152, longitude: 120.32833808217707),
                 description: "",
                 icon: "building",
                  color: Color.blue,
                 classrooms: [
                     (floor: "B1F", rooms: ["西001", "西002", "西003", "西004", "西005"]),
                     (floor: "1F", rooms: ["西101", "西102", "西103", "西104"]),
                     (floor: "3F", rooms: ["西302C"])
                 ]),
        Building(name: "東棟",
                 coordinate: CLLocationCoordinate2D(latitude: 22.650566872946502, longitude: 120.32920356354421),
                 description: "",
                 icon: "building",
                  color: Color.blue,
                 classrooms: [
                     (floor: "B1F", rooms: ["東001", "東002", "東003", "東004", "東005"]),
                     (floor: "1F", rooms: ["東104", "東105"]),
                     (floor: "2F", rooms: ["東201", "東203"]),
                     (floor: "3F", rooms: ["東304", "東305"])
                 ]),
        Building(name: "萊爾富",
                 coordinate: CLLocationCoordinate2D(latitude: 22.649755037673355, longitude: 120.32901559874364),
                 description: "",
                 icon: "storefront",
                  color: Color.green),
        Building(name: "電機館",
                 coordinate: CLLocationCoordinate2D(latitude: 22.64947532320891, longitude: 120.32855157660838),
                 description: "",
                 icon: "building",
                  color: Color.gray,
                 classrooms: [
                     (floor: "B1F", rooms: ["電B02","電B05","電B06","電小劇場"]),
                     (floor: "1F", rooms: ["電105","電106","慧芳講堂"]),
                     (floor: "4F", rooms: ["電401"]),
                     (floor: "5F", rooms: ["電503","電504","電505","電506"]),
                     (floor: "6F", rooms: ["電601","電603"]),
                 ]),
        Building(name: "模具館",
                 coordinate: CLLocationCoordinate2D(latitude: 22.64947532320891, longitude: 120.32913250623187),
                 description: "",
                 icon: "building",
                  color: Color.gray,
                 classrooms: [
                     (floor: "1F", rooms: ["模103","模111"]),
                     (floor: "2F", rooms: ["模205","模208","模210"]),
                     (floor: "3F", rooms: ["模308"]),
                     (floor: "5F", rooms: ["模501","模505","模510","模514"]),
                     (floor: "6F", rooms: ["模601","模603","模605"]),
                 ]),
        Building(name: "土木工程館",
                 coordinate: CLLocationCoordinate2D(latitude: 22.648918902987248, longitude: 120.32911384274722),
                 description: "",
                 icon: "building",
                  color: Color.gray,
                 classrooms: [
                     (floor: "1F", rooms: ["土101","土107"]),
                     (floor: "2F", rooms: ["土207"]),
                     (floor: "3F", rooms: ["土302A", "土308", "土309"]),
                     (floor: "4F", rooms: ["土401A","土408", "土409"]),
                     (floor: "5F", rooms: ["土502F","土503","土508","土509"]),
                     (floor: "6F", rooms: ["土608","土609"]),
                     (floor: "7F", rooms: ["土702", "土703", "土708", "土709"]),
                 ]),
        Building(name: "機械工程館",
                 coordinate: CLLocationCoordinate2D(latitude: 22.648282093812334, longitude: 120.3291390157567),
                 description: "",
                 icon: "building",
                  color: Color.gray,
                 classrooms: [
                     (floor: "B1F", rooms: ["機B02"]),
                     (floor: "1F", rooms: ["機101A","機102","機103", "M103A", "材料實驗室"]),
                     (floor: "2F", rooms: ["機203", "機204"]),
                     (floor: "3F", rooms: ["機304","機306","機307"]),
                     (floor: "4F", rooms: ["機402","機403","機404", "機407", "機408", "機409"]),
                 ]),
        Building(name: "中正堂",
                 coordinate: CLLocationCoordinate2D(latitude: 22.64928426315465, longitude: 120.32790094610567),
                 description: "",
                 icon: "building",
                  color: Color.gray),
        Building(name: "化材館",
                 coordinate: CLLocationCoordinate2D(latitude: 22.64897979412971, longitude: 120.32770782706619),
                 description: "",
                 icon: "building",
                  color: Color.gray,
                 classrooms: [
                     (floor: "B1F", rooms: ["化材B1-07(化001)"]),
                     (floor: "1F", rooms: ["曉東講堂"]),
                     (floor: "3F", rooms: ["化305"]),
                     (floor: "4F", rooms: ["化402"]),
                     (floor: "8F", rooms: ["化809","化812"])
                 ]),
        Building(name: "多功能實習工廠",
                 coordinate: CLLocationCoordinate2D(latitude: 22.649233, longitude: 120.327644),
                 description: "",
                 icon: "building",
                  color: Color.gray,
                 classrooms: [
                     (floor: "1F", rooms: ["多101"]),
                     (floor: "2F", rooms: ["多201"]),
                     (floor: "4F", rooms: ["多401"]),
                     (floor: "5F", rooms: ["多502"])
                 ]),
        Building(name: "司令台",
                 coordinate: CLLocationCoordinate2D(latitude: 22.648251466414806, longitude: 120.32783600364664),
                 description: "",
                 icon: "megaphone.fill",
                  color: Color.gray,
                 classrooms: [
                     (floor: "2F", rooms: ["司207", "司208"]),
                 ]),
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
}

struct JiangongMapView: View {
    
    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 22.651611, longitude: 120.328853),
            span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
        )
    )
    
    @State private var selectedBuilding: Building?
    
    // 校園建築
    let buildings = JiangongBuildings.all
    
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

        // 點擊建築顯示資訊
        .sheet(item: $selectedBuilding) { building in
            BuildingDetailSheet(building: building)
        }
    }
}

#Preview {
    JiangongMapView()
}
