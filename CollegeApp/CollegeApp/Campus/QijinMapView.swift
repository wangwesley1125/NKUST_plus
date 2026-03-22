//
//  QijinMapView.swift
//  CollegeApp
//
//  Created by Wesley Wang on 2026/3/15.
//

import SwiftUI
import MapKit

enum QijinBuildings {
    static let all: [Building] = [
        Building(name: "校門口",
                 coordinate: CLLocationCoordinate2D(latitude: 22.608711, longitude: 120.271963),
                 description: "旗津校區正門口",
                icon: "door.french.open",
                 color: .teal),
        Building(name: "渤海樓(學生宿舍)",
                 coordinate: CLLocationCoordinate2D(latitude: 22.60917106633049, longitude: 120.27217320069572),
                 description: "",
                 icon: "bed.double",
                  color: Color.blue),
        Building(name: "船舶機械實習工廠",
                 coordinate: CLLocationCoordinate2D(latitude: 22.60935033047928, longitude: 120.2725106020911),
                 description: "",
                 icon: "building",
                  color: Color.gray),
        Building(name: "船舶機械實習工廠",
                 coordinate: CLLocationCoordinate2D(latitude: 22.609291221928917, longitude: 120.27281192550456),
                 description: "",
                 icon: "building",
                  color: Color.gray),
        Building(name: "商船船員訓練中心",
                 coordinate: CLLocationCoordinate2D(latitude: 22.609291221928917, longitude: 120.27281192550456),
                 description: "",
                 icon: "building",
                  color: Color.gray),
        Building(name: "教學碼頭",
                 coordinate: CLLocationCoordinate2D(latitude: 22.609328, longitude: 120.273096),
                 description: "",
                 icon: "sailboat.fill",
                  color: Color.gray),
        Building(name: "行政大樓(鄭和樓)",
                 coordinate: CLLocationCoordinate2D(latitude: 22.608989140381926, longitude: 120.27310696848046),
                 description: "",
                 icon: "building",
                  color: Color.gray),
        Building(name: "教學實習綜合大樓",
                 coordinate: CLLocationCoordinate2D(latitude: 22.608630, longitude: 120.272723),
                 description: "",
                 icon: "building",
                  color: Color.gray,
                 classrooms: [
                     (floor: "1F", rooms: ["1101船舶機械工廠","1104輪機實驗室","1105船電實習教室","1110主輔機工廠","旗U101","旗U102","旗U103","旗U104"]),
                     (floor: "2F", rooms: ["1204海資多功能教室","1205海事風電研討室","旗U201","旗U202","旗U203","旗U204"]),
                     (floor: "3F", rooms: ["旗306海資電腦教室","旗307簡報室","旗U301","旗U302","旗U303","旗U304","旗U305階梯教室","旗U308輪機系會議室","旗U313海事機電研究","旗U314學士後培力專"]),
                     (floor: "4F", rooms: ["1405自動控制實驗室","1406電子實習實驗室","1409航海氣象教室","1410通用模擬教室","1411電子航儀教室","1412海圖","1413雷達模擬教室","旗402航技專題","旗U403","旗U404","旗U405","旗U406","旗U407","旗U408階梯教室"]),
                     (floor: "5F", rooms: ["旗U509","旗U510","旗U511","旗U512"]),
                     (floor: "6F", rooms: ["1608航海模擬資料室","1612貨油實驗室","1616雷達模擬教室","英語園區自學教室(1609)","旗U603","旗U604","旗U605","旗津1610電腦B","旗津1611語言教室"])
                 ]),
        Building(name: "海事工程實習大樓",
                 coordinate: CLLocationCoordinate2D(latitude: 22.608394, longitude: 120.273705),
                 description: "",
                 icon: "building",
                  color: Color.gray,
                 classrooms: [
                     (floor: "1F", rooms: ["海事實習教室101","海事實習教室102"]),
                 ]),
        Building(name: "立體機車停車場",
                 coordinate: CLLocationCoordinate2D(latitude: 22.607845233283363, longitude: 120.27271326031023),
                 description: "",
                 icon: "motorcycle",
                  color: Color.pink),
        Building(name: "普化、物實驗室",
                 coordinate: CLLocationCoordinate2D(latitude: 22.607684, longitude: 120.272957),
                 description: "",
                 icon: "flask.fill",
                  color: Color.green,
                 classrooms: [
                     (floor: "1F", rooms: ["101旗津物理實驗室"]),
                     (floor: "2F", rooms: ["201旗津化學實驗室"])
                 ]),
        Building(name: "艇庫",
                 coordinate: CLLocationCoordinate2D(latitude: 22.60873910306279, longitude: 120.27345355000048),
                 description: "",
                 icon: "sailboat.fill",
                  color: Color.gray),
        Building(name: "籃球場",
                 coordinate: CLLocationCoordinate2D(latitude: 22.608056939812027, longitude: 120.2732389732737),
                 description: "",
                 icon: "figure.basketball",
                  color: Color.orange),
        Building(name: "體育館",
                 coordinate: CLLocationCoordinate2D(latitude: 22.611750266626665, longitude: 120.27059959680412),
                 description: "",
                 icon: "figure.basketball",
                  color: Color.orange),
        Building(name: "教職員宿舍",
                 coordinate: CLLocationCoordinate2D(latitude: 22.61223382641597, longitude: 120.26999933244961),
                 description: "",
                 icon: "bed.double",
                  color: Color.blue),
        Building(name: "教職員宿舍",
                 coordinate: CLLocationCoordinate2D(latitude: 22.612554, longitude: 120.270239),
                 description: "",
                 icon: "bed.double",
                  color: Color.blue),
        Building(name: "圖書館",
                 coordinate: CLLocationCoordinate2D(latitude: 22.611959720651075, longitude: 120.27061195990814),
                 description: "",
                 icon: "book",
                  color: Color.blue),
        Building(name: "游泳池",
                 coordinate: CLLocationCoordinate2D(latitude: 22.61144411502106, longitude: 120.2709784325244),
                 description: "",
                 icon: "figure.open.water.swim",
                  color: Color.blue),
        Building(name: "滅火場",
                 coordinate: CLLocationCoordinate2D(latitude: 22.611628, longitude: 120.270985),
                 description: "",
                 icon: "fire.extinguisher.fill",
                  color: Color.pink)
    ]
}

struct QijinMapView: View {
    
    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 22.608805, longitude: 120.271993),
            span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
        )
    )
    
    @State private var selectedBuilding: Building?
    
    // 校園建築
    let buildings = QijinBuildings.all
    
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
        .presentationContentInteraction(.scrolls)
    }
}

#Preview {
    QijinMapView()
}
