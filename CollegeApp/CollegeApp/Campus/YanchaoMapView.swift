//
//  YanchaoMapView.swift
//  CollegeApp
//
//  Created by Wesley Wang on 2026/3/15.
//

import SwiftUI
import MapKit

enum YanchaoBuildings {
    static let all: [Building] = [
        Building(name: "校門口",
                 coordinate: CLLocationCoordinate2D(latitude: 22.772462, longitude: 120.400273),
                 description: "燕巢校區正門口",
                icon: "door.french.open",
                 color: .teal),
        Building(name: "停車場",
                 coordinate: CLLocationCoordinate2D(latitude: 22.77265513664243, longitude: 120.40063893346289),
                 description: "",
                 icon: "p.square.fill",
                  color: Color.blue),
        Building(name: "機車棚",
                 coordinate: CLLocationCoordinate2D(latitude: 22.77265940878065, longitude: 120.39979807315984),
                 description: "",
                 icon: "motorcycle",
                  color: Color.pink),
        Building(name: "7-ELEVEN",
                 coordinate: CLLocationCoordinate2D(latitude: 22.77247788989449, longitude: 120.39940685145297),
                 description: "",
                 icon: "storefront",
                  color: Color.green),
        Building(name: "多功能球場",
                 coordinate: CLLocationCoordinate2D(latitude: 22.77271801121566, longitude: 120.39882087080704),
                 description: "",
                 icon: "figure.basketball",
                  color: Color.orange),
        Building(name: "資源回收場",
                 coordinate: CLLocationCoordinate2D(latitude: 22.7726570327192, longitude: 120.3979109268858),
                 description: "",
                 icon: "arrow.3.trianglepath",
                  color: Color.gray),
        Building(name: "大學一橋",
                 coordinate: CLLocationCoordinate2D(latitude: 22.773911264221315, longitude: 120.4006362012409),
                 description: "",
                 icon: "road.lanes",
                  color: Color.gray),
        Building(name: "大學二橋",
                 coordinate: CLLocationCoordinate2D(latitude: 22.77342617805246, longitude: 120.39820525481308),
                 description: "",
                 icon: "road.lanes",
                  color: Color.gray),
        Building(name: "智善廳",
                 coordinate: CLLocationCoordinate2D(latitude: 22.774018928739476, longitude: 120.3978573433828),
                 description: "",
                 icon: "building",
                  color: Color.gray),
        Building(name: "人文社會學院",
                  coordinate: CLLocationCoordinate2D(latitude: 22.7742504476864, longitude: 120.39820307969825),
                  description: "",
                  icon: "building",
                   color: Color.gray,
                  classrooms: [
                      (floor: "2F", rooms: ["HS207","HS209","HS210","HS221","HS222"]),
                      (floor: "3F", rooms: ["HS304","HS305","HS313","HS314","HS315","HS316","HS319","HS327","HS328"]),
                      (floor: "4F", rooms: ["HS405","HS408","HS414","HS415","HS416","HS418","HS427"]),
                      (floor: "5F", rooms: ["HS507","HS508","HS509","HS514","HS516","HS517","HS519","HS528","HS529"]),
                      (floor: "6F", rooms: ["HS603","HS605","HS608","HS609"])
                  ]),
        Building(name: "行政大樓",
                  coordinate: CLLocationCoordinate2D(latitude: 22.77510880590793, longitude: 120.40129606110933),
                  description: "",
                  icon: "building",
                   color: Color.gray),
        Building(name: "圖書資訊大樓",
                  coordinate: CLLocationCoordinate2D(latitude: 22.776103150056958, longitude: 120.4009617570848),
                  description: "",
                  icon: "building",
                   color: Color.gray),
        Building(name: "景觀吊橋",
                 coordinate: CLLocationCoordinate2D(latitude: 22.77525074940993, longitude: 120.40203024283728),
                 description: "",
                 icon: "figure.walk",
                  color: Color.gray),
        Building(name: "樂知樓(男宿)",
                 coordinate: CLLocationCoordinate2D(latitude: 22.775309169561297, longitude: 120.40297776790166),
                 description: "",
                 icon: "bed.double",
                  color: Color.blue),
        Building(name: "詠絮樓",
                 coordinate: CLLocationCoordinate2D(latitude: 22.77537008842355, longitude: 120.40352286039284),
                 description: "",
                 icon: "building",
                  color: Color.gray),
        Building(name: "涵芳樓",
                 coordinate: CLLocationCoordinate2D(latitude: 22.77514092585854, longitude: 120.40368470118092),
                 description: "",
                 icon: "building",
                  color: Color.gray),
        Building(name: "開心農場",
                 coordinate: CLLocationCoordinate2D(latitude: 22.774150, longitude: 120.403370),
                 description: "",
                 icon: "apple.meditate",
                  color: Color.green),
        Building(name: "生態池",
                 coordinate: CLLocationCoordinate2D(latitude: 22.77340738297478, longitude: 120.40090947946895),
                 description: "",
                 icon: "bird.fill",
                  color: Color.green),
        Building(name: "管理學院大樓(二館)",
                  coordinate: CLLocationCoordinate2D(latitude: 22.773374229410397, longitude: 120.40204028313187),
                  description: "",
                  icon: "building",
                   color: Color.gray,
                  classrooms: [
                    (floor: "1F", rooms: ["MB101","MB104","MB105","MB107","MB108","MB109","MB110","MB112","MB113"]),
                    (floor: "2F", rooms: ["MB201","MB202","MB207","MB208","MB209","MB210"]),
                    (floor: "3F", rooms: ["MB303","MB304","MB322","MB323","MB324","MB325"]),
                    (floor: "4F", rooms: ["MB403A","MB404","MB422","MB423","MB424","MB425A","MB425B"]),
                    (floor: "5F", rooms: ["MB503","MB504","MB522","MB523","MB524","MB525A","MB525B"]),
                    (floor: "6F", rooms: ["MB602","MB603"])
                  ]),
        Building(name: "管理學院大樓(一館)",
                  coordinate: CLLocationCoordinate2D(latitude: 22.773523453519473, longitude: 120.40306334808744),
                  description: "",
                  icon: "building",
                   color: Color.gray,
                  classrooms: [
                    (floor: "1F", rooms: ["MA104","MA106"]),
                    (floor: "2F", rooms: ["MA202","MA203A","MA205","MA206","MA207","MA208","MA209","MA212","MA213","MA215","MA216","MA217B","MA218"]),
                    (floor: "3F", rooms: ["MA318","MA319","MA320","MA321","MA324","MA325"]),
                    (floor: "4F", rooms: ["MA409B","MA410A","MA421-AI","MA423A","MA423B"]),
                    (floor: "5F", rooms: ["MA503","MA504","MA505"])
                  ]),
        Building(name: "麗文書局",
                  coordinate: CLLocationCoordinate2D(latitude: 22.773684371210333, longitude: 120.40212183787902),
                  description: "",
                  icon: "pencil.and.ruler",
                   color: Color.orange)
    ]
}

struct YanchaoMapView: View {
    
    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 22.772465, longitude: 120.400284),
            span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
        )
    )
    
    @State private var selectedBuilding: Building?
    
    // 校園建築
    let buildings = YanchaoBuildings.all
    
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
    YanchaoMapView()
}
