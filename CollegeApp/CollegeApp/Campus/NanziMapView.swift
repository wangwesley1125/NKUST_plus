//
//  NanziMapView.swift
//  CollegeApp
//
//  Created by Wesley Wang on 2026/3/15.
//

import SwiftUI
import MapKit

enum NanziBuildings {
    static let all: [Building] = [
        Building(name: "校門口",
                 coordinate: CLLocationCoordinate2D(latitude: 22.72476877387302, longitude: 120.31467204016155),
                 description: "楠梓校區正門口",
                icon: "door.french.open",
                 color: .teal),
        Building(name: "立誠樓",
                 coordinate: CLLocationCoordinate2D(latitude: 22.72542799905657, longitude: 120.31411812795353),
                 description: "",
                 icon: "building",
                  color: Color.gray,
                 classrooms: [
                     (floor: "1F", rooms: ["4102階梯教室","4103教室","4106教室","4107教室","4108教室","4109教室"]),
                     (floor: "2F", rooms: ["4201教室","4204教室","4205書報討論室","4206電腦實驗室"]),
                     (floor: "3F", rooms: ["4306多媒體實驗室"]),
                     (floor: "4F", rooms: ["4405技能訓練工廠","4406專題製作室"]),
                     (floor: "5F", rooms: ["4501DSP實驗室","4502印刷電路製作室","4504數位串流實驗室","4507電子實驗室"])
                 ]),
        Building(name: "致遠樓",
                 coordinate: CLLocationCoordinate2D(latitude: 22.72582768176294, longitude: 120.31384121108714),
                 description: "",
                 icon: "building",
                  color: Color.gray,
                 classrooms: [
                     (floor: "1F", rooms: ["3106海洋資源專業教室"]),
                     (floor: "2F", rooms: ["3201專業教室","3202教室","3203教室","3204教室","3205教室","3206教室"]),
                     (floor: "4F", rooms: ["3401電腦教室(一)"]),
                     (floor: "5F", rooms: ["3501供應鏈發展教室","3508供應鏈管理教室"])
                 ]),
        Building(name: "寰宇樓",
                 coordinate: CLLocationCoordinate2D(latitude: 22.726257069135166, longitude: 120.31411606955142),
                 description: "",
                 icon: "building",
                  color: Color.gray,
                 classrooms: [
                     (floor: "1F", rooms: ["2102英語教學教室","2104語言學習園區","2105教室"]),
                     (floor: "2F", rooms: ["2202教室","2203實驗室","2204階梯教室","2209專題教室","2210專題教室"]),
                     (floor: "3F", rooms: ["2304資訊科技研討室","2310教室"]),
                     (floor: "4F", rooms: ["2401教室","2402教室","2403電腦教室(二)","2407多功能階梯教室","2408商資創新研討室"]),
                     (floor: "5F", rooms: ["2501流通教學平台","2505綠色運籌中心","2506電腦輔助電話調查","2507教室","2508教室"])
                 ]),
        Building(name: "行政大樓",
                 coordinate: CLLocationCoordinate2D(latitude: 22.726485677888277, longitude: 120.31468842851496),
                 description: "",
                 icon: "building",
                  color: Color.gray),
        Building(name: "弘德樓",
                 coordinate: CLLocationCoordinate2D(latitude: 22.726257069135166, longitude: 120.31519179778198),
                 description: "",
                 icon: "building",
                  color: Color.gray,
                 classrooms: [
                     (floor: "1F", rooms: ["5102教室","5103教室","5109教室","5110階梯教室"]),
                     (floor: "2F", rooms: ["5202教室","5203教室","5208海工所實驗室"]),
                     (floor: "3F", rooms: ["5304教室","5305造船專業教室","5306機電整合實驗室"]),
                     (floor: "4F", rooms: ["5402流體力學實驗室","5403船用流力實驗室","5407多用途教室"]),
                     (floor: "5F", rooms: ["5502振動實驗室","5505物理實驗室","5506物理實驗室"])
                 ]),
        Building(name: "大仁樓",
                 coordinate: CLLocationCoordinate2D(latitude: 22.725858770497993, longitude: 120.3154703117419),
                 description: "",
                 icon: "building",
                  color: Color.gray,
                 classrooms: [
                     (floor: "1F", rooms: ["6104教室","6105教室","6106教室","6107教室","6108階梯教室"]),
                     (floor: "2F", rooms: ["6203元件測量實驗室","6204元件模組實驗室"]),
                     (floor: "3F", rooms: ["6304半導體會議室"]),
                     (floor: "4F", rooms: ["6404電子電路實驗室"]),
                     (floor: "5F", rooms: ["6503客製化實驗室","6504階梯教室","6505微控器實驗室","6501SOC實驗室"])
                 ]),
        Building(name: "大信樓",
                 coordinate: CLLocationCoordinate2D(latitude: 22.725434545822086, longitude: 120.3151585805207),
                 description: "",
                 icon: "building",
                  color: Color.gray,
                 classrooms: [
                     (floor: "1F", rooms: ["7103教室","7104教室","7107海事學院會議室","7109教室","7110階梯教室"]),
                     (floor: "2F", rooms: ["7202教室","7203教室","7204教室","7205微型教室","7208AI教室"]),
                     (floor: "3F", rooms: ["7301短期學者訪問室","7304海環大會議室"]),
                     (floor: "5F", rooms: ["7501環境共同實驗室","7508研究生研習室"])
                 ]),
        Building(name: "停車場",
                 coordinate: CLLocationCoordinate2D(latitude: 22.72705837650434, longitude: 120.31510747708352),
                 description: "",
                 icon: "p.square.fill",
                  color: Color.blue),
        Building(name: "司令台",
                 coordinate: CLLocationCoordinate2D(latitude: 22.727145577315564, longitude: 120.31538854621739),
                 description: "",
                 icon: "megaphone.fill",
                  color: Color.gray),
        Building(name: "體育館",
                 coordinate: CLLocationCoordinate2D(latitude: 22.727411892973223, longitude: 120.31679644712814),
                 description: "",
                 icon: "figure.basketball",
                  color: Color.orange),
        Building(name: "運動場",
                 coordinate: CLLocationCoordinate2D(latitude: 22.727138506987647, longitude: 120.31592768795886),
                 description: "",
                 icon: "figure.run",
                  color: Color.orange),
        Building(name: "科技潛水暨水域運動教學發展中心",
                 coordinate: CLLocationCoordinate2D(latitude: 22.72712672309625, longitude: 120.31738158198347),
                 description: "",
                 icon: "figure.open.water.swim",
                  color: Color.blue,
                 classrooms: [
                     (floor: "1~3F", rooms: ["潛水池"])
                 ]),
        Building(name: "水產食品實習大樓附設實習商店",
                 coordinate: CLLocationCoordinate2D(latitude: 22.72672371341869, longitude: 120.31709284729953),
                 description: "",
                 icon: "building",
                  color: Color.gray,
                 classrooms: [
                     (floor: "2F", rooms: ["冷凍工程教室","中餐烘焙教室"]),
                     (floor: "3F", rooms: ["水食工廠專業教室","水食工廠階梯教室"])
                 ]),
        Building(name: "籃球場",
                 coordinate: CLLocationCoordinate2D(latitude: 22.726165154177654, longitude: 120.31732792333743),
                 description: "",
                 icon: "figure.basketball",
                  color: Color.orange),
        Building(name: "排球場",
                 coordinate: CLLocationCoordinate2D(latitude: 22.72631834575532, longitude: 120.31683477476618),
                 description: "",
                 icon: "figure.volleyball",
                  color: Color.yellow),
        Building(name: "網球場",
                 coordinate: CLLocationCoordinate2D(latitude: 22.726037887198057, longitude: 120.3168245540704),
                 description: "",
                 icon: "figure.tennis",
                  color: Color.green),
        Building(name: "沙灘排球場",
                 coordinate: CLLocationCoordinate2D(latitude: 22.726035530401024, longitude: 120.31647705041395),
                 description: "",
                 icon: "figure.volleyball",
                  color: Color.yellow),
        Building(name: "造船實習工廠",
                 coordinate: CLLocationCoordinate2D(latitude: 22.725656085539782, longitude: 120.31723082672919),
                 description: "",
                 icon: "building",
                  color: Color.gray,
                 classrooms: [
                     (floor: "1~3F", rooms: ["造船實習工廠-1","造船實習工廠-2","造船實習工廠-3","造船實習工廠-4","造船實習工廠-5","造船實習工廠-6","造船實習工廠-7","造船實習工廠-8","造船實習工廠-9","造船實習工廠-10"])
                 ]),
        Building(name: "海天樓",
                 coordinate: CLLocationCoordinate2D(latitude: 22.7253119917825, longitude: 120.3166661332875),
                 description: "",
                 icon: "building",
                  color: Color.gray,
                 classrooms: [
                     (floor: "1F", rooms: ["10101教室","10102教室","10103教室","10104教室"]),
                     (floor: "2F", rooms: ["10201教室","10202教室","10203教室","10204教室","10205教室","10206教室","10207教室","10208教室"]),
                     (floor: "3F", rooms: ["A305教室","10307階梯教室"]),
                     (floor: "4F", rooms: ["10401多媒體通識教室","10403多媒體藝文教室","10405多媒體音樂教室"])
                 ]),
        Building(name: "藝文中心",
                 coordinate: CLLocationCoordinate2D(latitude: 22.725509963638288, longitude: 120.31332396559789),
                 description: "",
                 icon: "building",
                  color: Color.purple),
        Building(name: "厚生樓",
                 coordinate: CLLocationCoordinate2D(latitude: 22.725654460240044, longitude: 120.31293933312811),
                 description: "",
                 icon: "building",
                  color: Color.gray,
                 classrooms: [
                     (floor: "1F", rooms: ["A11108-2水食系多功能教室","A11114專業教室E","A11127漁撈作業實習","A11128專業教室F","121-1教室"]),
                     (floor: "2F", rooms: ["A11203漁管系會議室","A11212-5水食系會議室","212-3專業教室A","212-4專業教室B","213-6漁航科技實驗室","240-1專業教室C","240-2專業教室D"]),
                     (floor: "3F", rooms: ["A11301院級生物實驗室","A11309食品檢驗分析實驗","A11313院級生化分析實驗","A11314院級微生物實驗室","A11315-2水圈會議室","317-1研究生教室B","317-2研究生教室A"]),
                     (floor: "4F", rooms: ["A11415海生系實驗室"]),
                     (floor: "5F", rooms: ["A11515院級研討室A","A11516院級研討室B","A11527海生系研究生討論"]),
                     (floor: "7F", rooms: ["A11714-2水食所專題","A11719階梯教室","A11726-專業教室"])
                 ]),
        Building(name: "樂群樓",
                 coordinate: CLLocationCoordinate2D(latitude: 22.725842482304497, longitude: 120.31230901403248),
                 description: "",
                 icon: "building",
                  color: Color.gray,
                 classrooms: [
                     (floor: "1F", rooms: ["8107教室","8108教室","8109階梯教室"]),
                     (floor: "2F", rooms: ["8201化學教學教室","8202教室","8204教室","8206教室"]),
                     (floor: "3F", rooms: ["8302系大會議室","8305系小會議室"]),
                     (floor: "4F", rooms: ["8404魚類學實驗室"]),
                     (floor: "5F", rooms: ["8504水質分析實驗室","8508水產動物病理實驗室"])
                 ]),
        Building(name: "英才樓",
                 coordinate: CLLocationCoordinate2D(latitude: 22.72609977523596, longitude: 120.31238411588089),
                 description: "",
                 icon: "building",
                  color: Color.gray,
                 classrooms: [
                     (floor: "B1F", rooms: ["9001創客教室","9003會議室","9005海洋牧場"]),
                     (floor: "1F", rooms: ["9102教室","9103教室"]),
                     (floor: "3F", rooms: ["化學實驗室"])
                 ]),
        Building(name: "停車場",
                 coordinate: CLLocationCoordinate2D(latitude: 22.72642881262024, longitude: 120.31160627528313),
                 description: "",
                 icon: "p.square.fill",
                  color: Color.blue),
        Building(name: "學生活動中心",
                 coordinate: CLLocationCoordinate2D(latitude: 22.726589620072655, longitude: 120.31262551471153),
                 description: "",
                 icon: "figure.basketball",
                  color: Color.orange),
        Building(name: "圖書資訊視聽館",
                 coordinate: CLLocationCoordinate2D(latitude: 22.726658890915772, longitude: 120.31346236387954),
                 description: "",
                 icon: "book",
                  color: Color.blue,
                classrooms: [
                    (floor: "5F", rooms: ["11504電腦教室(A)","11505電腦教室(B)","11511CAD教室"])
                ]),
        Building(name: "慧海樓",
                 coordinate: CLLocationCoordinate2D(latitude: 22.727119046345106, longitude: 120.31338457984445),
                 description: "",
                 icon: "building",
                  color: Color.gray),
        Building(name: "東海樓",
                 coordinate: CLLocationCoordinate2D(latitude: 22.727213056402693, longitude: 120.31297151967817),
                 description: "",
                 icon: "building",
                  color: Color.gray),
        Building(name: "黃海樓",
                 coordinate: CLLocationCoordinate2D(latitude: 22.727517351675626, longitude: 120.31258796380048),
                 description: "",
                 icon: "building",
                  color: Color.gray),
        Building(name: "南海樓",
                 coordinate: CLLocationCoordinate2D(latitude: 22.72719573876862, longitude: 120.31221781897615),
                 description: "",
                 icon: "building",
                  color: Color.gray),
        Building(name: "7-ELEVEN",
                 coordinate: CLLocationCoordinate2D(latitude: 22.726965661378863, longitude: 120.31288568898525),
                 description: "",
                 icon: "storefront",
                  color: Color.green)
    ]
}

struct NanziMapView: View {
    
    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 22.724602, longitude: 120.314650),
            span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
        )
    )
    
    @State private var selectedBuilding: Building?
    
    // 校園建築
    let buildings = NanziBuildings.all
    
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
    NanziMapView()
}
