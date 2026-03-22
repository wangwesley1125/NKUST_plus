//
//  DiyiMapView.swift
//  CollegeApp
//
//  Created by Wesley Wang on 2026/3/15.
//

import SwiftUI
import MapKit

enum DiyiBuildings {
    static let all: [Building] = [
        Building(name: "西區校門口",
                 coordinate: CLLocationCoordinate2D(latitude: 22.751763917724624, longitude: 120.33147661362545),
                 description: "卓越路校門口",
                icon: "door.french.open",
                 color: .teal),
        Building(name: "機車棚",
                 coordinate: CLLocationCoordinate2D(latitude: 22.752431762124747, longitude: 120.33066122207738),
                 description: "樂群樓機車停車場",
                 icon: "motorcycle",
                  color: Color.pink),
        Building(name: "樂群樓(女宿)",
                 coordinate: CLLocationCoordinate2D(latitude: 22.752570277591047, longitude: 120.3299102036017),
                 description: "",
                 icon: "bed.double",
                  color: Color.pink),
        Building(name: "產業創新園區",
                 coordinate: CLLocationCoordinate2D(latitude: 22.75222627037895, longitude: 120.32855343476429),
                 description: "",
                 icon: "building",
                  color: Color.gray,
                 classrooms: [
                     (floor: "3F", rooms: ["H303"]),
                 ]),
        Building(name: "籃球場",
                 coordinate: CLLocationCoordinate2D(latitude: 22.753324497945144, longitude: 120.3272391523377),
                 description: "",
                 icon: "figure.basketball",
                  color: Color.orange),
        Building(name: "溜冰場",
                 coordinate: CLLocationCoordinate2D(latitude: 22.753403649138825, longitude: 120.32786678922146),
                 description: "",
                 icon: "figure.skateboarding",
                  color: Color.blue),
        Building(name: "壘球場",
                 coordinate: CLLocationCoordinate2D(latitude: 22.754415296307485, longitude: 120.32754224195054),
                 description: "",
                 icon: "figure.baseball",
                  color: Color.green),
        Building(name: "運動場",
                 coordinate: CLLocationCoordinate2D(latitude: 22.753764775883536, longitude: 120.32892357960179),
                 description: "",
                 icon: "figure.run",
                  color: Color.green),
        Building(name: "籃球場",
                 coordinate: CLLocationCoordinate2D(latitude: 22.75320824454967, longitude: 120.330060836223),
                 description: "",
                 icon: "figure.basketball",
                  color: Color.orange),
        Building(name: "網球場",
                 coordinate: CLLocationCoordinate2D(latitude: 22.75409374667951, longitude: 120.33004206074511),
                 description: "",
                 icon: "tennisball.fill",
                  color: Color.green),
        Building(name: "游泳池",
                 coordinate: CLLocationCoordinate2D(latitude: 22.754397982119887, longitude: 120.33149581804564),
                 description: "",
                 icon: "figure.open.water.swim",
                  color: Color.blue),
        Building(name: "敬業樓(男宿)",
                 coordinate: CLLocationCoordinate2D(latitude: 22.7554516703778, longitude: 120.33182304755766),
                 description: "",
                 icon: "bed.double",
                  color: Color.blue),
        Building(name: "機車棚",
                 coordinate: CLLocationCoordinate2D(latitude: 22.75654739858988, longitude: 120.33169430150834),
                 description: "",
                 icon: "motorcycle",
                  color: Color.pink),
        Building(name: "籃球場",
                 coordinate: CLLocationCoordinate2D(latitude: 22.75692335748664, longitude: 120.33193838252399),
                 description: "",
                 icon: "figure.basketball",
                  color: Color.orange),
        Building(name: "鴴池(生態池)",
                 coordinate: CLLocationCoordinate2D(latitude: 22.753549584039096, longitude: 120.33146094931341),
                 description: "",
                 icon: "bird.fill",
                  color: Color.green),
        Building(name: "大學橋",
                 coordinate: CLLocationCoordinate2D(latitude: 22.75472154244634, longitude: 120.33362515890246),
                 description: "",
                 icon: "road.lanes",
                  color: Color.gray),
        Building(name: "智慧防災實作工場",
                 coordinate: CLLocationCoordinate2D(latitude: 22.753578567037376, longitude: 120.33529839904105),
                 description: "",
                 icon: "building",
                  color: Color.gray,
                 classrooms: [
                     (floor: "1F", rooms: ["P102"]),
                     (floor: "2F", rooms: ["P202"]),
                     (floor: "3F", rooms: ["P302"])
                 ]),
        Building(name: "南區毒災中心",
                 coordinate: CLLocationCoordinate2D(latitude: 22.753889538387615, longitude: 120.33559288200689),
                 description: "",
                 icon: "building",
                  color: Color.gray),
        Building(name: "學生活動中心",
                 coordinate: CLLocationCoordinate2D(latitude: 22.754659396240474, longitude: 120.33540802136463),
                 description: "7-ELEVEN 高科大門市 & 圖書文具部",
                 icon: "storefront.fill",
                  color: Color.orange),
        Building(name: "水舞廣場",
                 coordinate: CLLocationCoordinate2D(latitude: 22.755061400722205, longitude: 120.33477956826505),
                 description: "",
                 icon: "water.waves.and.arrow.trianglehead.up",
                  color: Color.blue),
        Building(name: "圖書資訊大樓",
                 coordinate: CLLocationCoordinate2D(latitude: 22.75571778487593, longitude: 120.33520079666971),
                 description: "",
                 icon: "building",
                  color: Color.gray,
                 classrooms: [
                     (floor: "B1F", rooms: ["J001","J009","實作區B","木工區","創夢工場電子區"]),
                     (floor: "1F", rooms: ["J124"]),
                 ]),
        Building(name: "財經學院",
                 coordinate: CLLocationCoordinate2D(latitude: 22.756202015890334, longitude: 120.33485596933536),
                 description: "",
                 icon: "building",
                  color: Color.gray,
                 classrooms: [
                     (floor: "B1F", rooms: ["E001","E002","E003","E004","E005","E006","E007","E008","E009","E010","E011","E012","E013","E014","E015","E016"]),
                     (floor: "1F", rooms: ["E101","E102","E103","E104","E105","E106","E107","E108","E109","E110","E113","E115","E116","E117","E118","E119","E120"]),
                     (floor: "2F", rooms: ["E201","E202","E203","E204","E205","E206","E207","E209","E210","E211","E212","E213","E214","E216","E217","E220"]),
                     (floor: "3F", rooms: ["E301","E302","E303","E304","E305","E306","E307","E308","E309","E310","E311","E312","E313","E314","E315","E317","E318","E319"]),
                     (floor: "4F", rooms: ["E403","E416","E419","E420","E421","E422","E423","E424","E425"]),
                     (floor: "5F", rooms: ["E514","E522","E525","E534"])
                 ]),
        Building(name: "外語學院",
                 coordinate: CLLocationCoordinate2D(latitude: 22.756639615540866, longitude: 120.33615568367877),
                 description: "",
                 icon: "building",
                  color: Color.gray,
                 classrooms: [
                     (floor: "B1F", rooms: ["D009"]),
                     (floor: "1F", rooms: ["D101","D102多功能教室","D103多功能教室","D104","D105","D106","D107","D108","D109","D110電腦教室","D111"]),
                     (floor: "2F", rooms: ["D201","D202電腦教室","D203","D204文化教室","D205電腦教室","D206電腦教室","D208電腦教室","D209電腦教室"]),
                     (floor: "3F", rooms: ["D301文化教室","D302","D308"]),
                     (floor: "4F", rooms: ["D414","D415","D416","D417","D418"]),
                     (floor: "5F", rooms: ["D516","D517"])
                 ]),
        Building(name: "管理學院",
                 coordinate: CLLocationCoordinate2D(latitude: 22.75714418518805, longitude: 120.33734636744386),
                 description: "",
                 icon: "building",
                  color: Color.gray,
                 classrooms: [
                     (floor: "1F", rooms: ["C103","C104","C116","C117","C120","C123實驗教室","C124冷鏈實驗室","C125"]),
                     (floor: "2F", rooms: ["C203","C204","C218","C219","C220","C222"]),
                     (floor: "3F", rooms: ["C333","C338","C340","C345","C356","C359","C363"]),
                     (floor: "4F", rooms: ["C433","C434","C442","C443","C444","C445","C446","C448"])
                 ]),
        Building(name: "電資學院",
                 coordinate: CLLocationCoordinate2D(latitude: 22.757768089545554, longitude: 120.3379745866955),
                 description: "",
                 icon: "building",
                  color: Color.gray,
                 classrooms: [
                     (floor: "1F", rooms: ["B113","B115","B116","B118","B119","B120","B121","B122","B123","B124","B125"]),
                     (floor: "2F", rooms: ["B201","B201-8","B211電腦教室","B222","B225","B229"]),
                     (floor: "3F", rooms: ["B323","B337 ","B339","B342","B344","B345"]),
                     (floor: "4F", rooms: ["B442","B443 ","B444","B445"]),
                     (floor: "5F", rooms: ["B501","B504 ","B506","B508"])
                 ]),
        Building(name: "工學院",
                  coordinate: CLLocationCoordinate2D(latitude: 22.758378275850113, longitude: 120.3380465682743),
                  description: "",
                  icon: "building",
                   color: Color.gray,
                  classrooms: [
                    (floor: "1F", rooms: ["F106","F107","F108","F109","F124","F126","F128","F129","F131","F146","F147","F151"]),
                    (floor: "2F", rooms: ["F208","F209","F223","F224","F225"]),
                    (floor: "4F", rooms: ["F410","F452 ","F455","F456"]),
                    (floor: "5F", rooms: ["F553","F554"])
                  ]),
        Building(name: "教師研究大樓",
                  coordinate: CLLocationCoordinate2D(latitude: 22.757841040842898, longitude: 120.33893969278456),
                  description: "",
                  icon: "building",
                   color: Color.gray),
        Building(name: "跨領域實作工廠",
                  coordinate: CLLocationCoordinate2D(latitude: 22.756954524048076, longitude: 120.33984482203078),
                  description: "",
                  icon: "building",
                   color: Color.gray,
                  classrooms: [
                      (floor: "1F", rooms: ["S109"]),
                      (floor: "2F", rooms: ["S202","S204","S210","S211"])
                  ]),
        Building(name: "智慧製造實作工廠",
                  coordinate: CLLocationCoordinate2D(latitude: 22.756676108314508, longitude: 120.34002358961506),
                  description: "",
                  icon: "building",
                   color: Color.gray,
                  classrooms: [
                      (floor: "2F", rooms: ["T212","T210"])
                  ]),
        Building(name: "實作工廠",
                  coordinate: CLLocationCoordinate2D(latitude: 22.757395439159467, longitude: 120.34038336557204),
                  description: "",
                  icon: "building",
                   color: Color.gray,
                  classrooms: [
                      (floor: "1F", rooms: ["V101","V106"])
                  ]),
        Building(name: "職務宿舍",
                 coordinate: CLLocationCoordinate2D(latitude: 22.758546559558063, longitude: 120.34080222175933),
                 description: "",
                 icon: "bed.double",
                  color: Color.brown),
        Building(name: "第二停車場",
                 coordinate: CLLocationCoordinate2D(latitude: 22.75875900588937, longitude: 120.33926928614007),
                 description: "",
                 icon: "p.square.fill",
                  color: Color.blue),
        Building(name: "第一停車場",
                 coordinate: CLLocationCoordinate2D(latitude: 22.758538388533587, longitude: 120.33682810820846),
                 description: "",
                 icon: "p.square.fill",
                  color: Color.blue),
        Building(name: "東區校門口",
                 coordinate: CLLocationCoordinate2D(latitude: 22.758537410117043, longitude: 120.33626519809775),
                 description: "大學路校門口",
                icon: "door.french.open",
                 color: .teal),
        Building(name: "機車棚",
                 coordinate: CLLocationCoordinate2D(latitude: 22.758327050136636, longitude: 120.33554600964341),
                 description: "",
                 icon: "motorcycle",
                  color: Color.pink),
        Building(name: "第四停車場",
                 coordinate: CLLocationCoordinate2D(latitude: 22.75769045685481, longitude: 120.33418598506351),
                 description: "",
                 icon: "p.square.fill",
                  color: Color.blue),
        Building(name: "第六停車場",
                 coordinate: CLLocationCoordinate2D(latitude: 22.75617836224247, longitude: 120.33416308362759),
                 description: "",
                 icon: "p.square.fill",
                  color: Color.blue)
    ]
}

struct DiyiMapView: View {
    
    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 22.751928, longitude: 120.331460),
            span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
        )
    )
    
    @State private var selectedBuilding: Building?
    
    // 校園建築
    let buildings = DiyiBuildings.all
    
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
            // 有教室資料就給大一點的 sheet
            .presentationDetents(
                building.classrooms.isEmpty
                ? [.height(110)]
                : [.height(250)]
            )
        }
    }
}

#Preview {
    DiyiMapView()
}
