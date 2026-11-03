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

    /// 各校區的建築資料（地圖、教室搜尋、停車命名共用）
    var buildings: [Building] {
        switch self {
        case .jiangong: return JiangongBuildings.all
        case .diyi:     return DiyiBuildings.all
        case .yanchao:  return YanchaoBuildings.all
        case .qijin:    return QijinBuildings.all
        case .nanzi:    return NanziBuildings.all
        }
    }

    /// 找出離某個座標最近的校區（停車位置用來自動切換校區）
    static func nearest(to coordinate: CLLocationCoordinate2D) -> Campus {
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return allCases.min {
            CLLocation(latitude: $0.center.latitude, longitude: $0.center.longitude).distance(from: target) <
            CLLocation(latitude: $1.center.latitude, longitude: $1.center.longitude).distance(from: target)
        } ?? .jiangong
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

/// GPS 校正時發現人離車太遠，詢問是否移動
private struct MovePrompt {
    let vehicle: VehicleType
    let distance: CLLocationDistance
    let location: CLLocation
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

    // MARK: 停車位置
    @State private var parking = ParkingStore()
    @State private var noteDraft = ""
    /// 備註是不是系統依附近地點自動填的（用來改提示文字）
    @State private var noteIsSuggested = false
    /// 正在編輯備註的車種（nil = 沒有）
    @State private var noteVehicle: VehicleType?
    /// 等待確認「重新記錄」的車種
    @State private var overwriteVehicle: VehicleType?
    /// 等待確認「清除」的車種
    @State private var clearVehicle: VehicleType?
    /// GPS 校正發現離車太遠時的詢問
    @State private var movePrompt: MovePrompt?

    // 手動拖曳調整（Uber 式：地圖中央固定圖釘，拖地圖對準）
    @State private var adjustingVehicle: VehicleType?
    @State private var adjustCenter: CLLocationCoordinate2D?

    // 上方小提示
    @State private var toastMessage: String?
    @State private var toastTask: Task<Void, Never>?

    var buildings: [Building] { selectedCampus.buildings }

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
                .disabled(adjustingVehicle != nil)

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

                    // 停車位置（機車 / 汽車，不分校區，永遠顯示）
                    // 正在拖曳調整的那台先藏起來，改用畫面中央的圖釘
                    ForEach(VehicleType.allCases) { vehicle in
                        if let spot = parking.spot(for: vehicle), adjustingVehicle != vehicle {
                            // 定位誤差範圍（手動調整過的就不畫）
                            if !spot.wasAdjusted {
                                MapCircle(center: spot.coordinate, radius: max(spot.accuracy, 5))
                                    .foregroundStyle(vehicle.color.opacity(0.15))
                                    .stroke(vehicle.color.opacity(0.5), lineWidth: 1)
                            }

                            Annotation(spot.note.isEmpty ? "我的\(vehicle.name)" : spot.note,
                                       coordinate: spot.coordinate) {
                                Image(systemName: vehicle.icon)
                                    .font(.title3)
                                    .foregroundStyle(.white)
                                    .padding(8)
                                    .background(vehicle.color)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(.white, lineWidth: 2))
                                    .shadow(radius: 3)
                            }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
                .mapControls {
                    MapUserLocationButton()
                }
                // 拖曳調整時，持續記下地圖中心（= 圖釘尖端的位置）
                .onMapCameraChange(frequency: .continuous) { context in
                    if adjustingVehicle != nil {
                        adjustCenter = context.region.center
                    }
                }
                // 拖曳調整：畫面中央固定圖釘
                .overlay {
                    if let vehicle = adjustingVehicle {
                        centerPin(vehicle)
                    }
                }
                // 右下角：機車 / 汽車停車按鈕（調整時隱藏）
                .overlay(alignment: .bottomTrailing) {
                    if adjustingVehicle == nil {
                        VStack(spacing: 10) {
                            ForEach(VehicleType.allCases) { vehicle in
                                vehicleButton(vehicle)
                            }
                        }
                        .padding(.trailing, 12)
                        .padding(.bottom, 16)
                    }
                }
                // 拖曳調整：底部確認列
                .overlay(alignment: .bottom) {
                    if let vehicle = adjustingVehicle {
                        adjustBar(vehicle)
                    }
                }
                // 上方小提示
                .overlay(alignment: .top) {
                    if let toastMessage {
                        Text(toastMessage)
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.regularMaterial)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
                            .padding(.top, 10)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
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
            // 備註（記錄後 / 編輯時）：可能已預填附近地點，使用者按「儲存」才會存
            .alert("停車備註",
                   isPresented: isPresent($noteVehicle),
                   presenting: noteVehicle) { vehicle in
                TextField("例如：燕巢 B 停車場第 3 排", text: $noteDraft)
                Button("儲存") { parking.updateNote(noteDraft, for: vehicle) }
                Button("略過", role: .cancel) {}
            } message: { vehicle in
                if noteIsSuggested {
                    Text("已依附近地點幫你的\(vehicle.name)填好名稱，可以修改後按「儲存」")
                } else {
                    Text("幫你的\(vehicle.name)加個備註，下次比較好找（可略過）")
                }
            }
            // 重新記錄前確認
            .confirmationDialog("要重新記錄停車位置嗎？",
                                isPresented: isPresent($overwriteVehicle),
                                titleVisibility: .visible,
                                presenting: overwriteVehicle) { vehicle in
                Button("把\(vehicle.name)位置移到目前位置") {
                    Task { await recordParking(vehicle) }
                }
                Button("取消", role: .cancel) {}
            } message: { _ in
                Text("會用你現在站的位置取代原本的停車點。")
            }
            // GPS 校正時離車太遠
            .confirmationDialog("你離停車位置約 \(Int(movePrompt?.distance ?? 0)) 公尺",
                                isPresented: isPresent($movePrompt),
                                titleVisibility: .visible,
                                presenting: movePrompt) { prompt in
                Button("把\(prompt.vehicle.name)移到目前位置") {
                    parking.replace(with: prompt.location, for: prompt.vehicle)
                    goToParking(prompt.vehicle)
                    Task { await promptNote(for: prompt.vehicle, suggest: true) }
                }
                Button("保留原位置", role: .cancel) {}
            } message: { _ in
                Text("GPS 校正要站在車旁邊才有效。如果你已經離開，請保留原位置。")
            }
            .confirmationDialog("要清除停車位置嗎？",
                                isPresented: isPresent($clearVehicle),
                                titleVisibility: .visible,
                                presenting: clearVehicle) { vehicle in
                Button("清除\(vehicle.name)停車位置", role: .destructive) {
                    withAnimation { parking.clear(vehicle) }
                }
                Button("取消", role: .cancel) {}
            }
            // 定位失敗 / 權限被拒
            .alert("無法取得位置", isPresented: parkingErrorBinding) {
                if parking.isPermissionDenied {
                    Button("前往設定") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                Button("好", role: .cancel) {}
            } message: {
                Text(parking.errorMessage ?? "")
            }
        }
    }

    // MARK: - 右下角車輛按鈕

    /// 沒記錄：點一下直接記錄目前位置
    /// 已記錄：點一下開選單
    @ViewBuilder
    private func vehicleButton(_ vehicle: VehicleType) -> some View {
        if let spot = parking.spot(for: vehicle) {
            Menu {
                Section(menuTitle(vehicle, spot)) {
                    Button("前往停車位置", systemImage: "location.viewfinder") {
                        goToParking(vehicle)
                    }
                    Button("步行導航", systemImage: "figure.walk") {
                        parking.openWalkingDirections(for: vehicle)
                    }
                }
                Section("調整位置") {
                    if !spot.wasAdjusted {
                        Button("GPS 校正（站在車旁按）", systemImage: "scope") {
                            Task { await refineParking(vehicle) }
                        }
                    }
                    Button("在地圖上拖曳調整", systemImage: "hand.draw") {
                        startAdjusting(vehicle)
                    }
                    Button("重新記錄（移到目前位置）", systemImage: "arrow.triangle.2.circlepath") {
                        overwriteVehicle = vehicle
                    }
                }
                Button("編輯備註", systemImage: "square.and.pencil") {
                    Task { await promptNote(for: vehicle, suggest: spot.note.isEmpty) }
                }
                Button("清除停車位置", systemImage: "trash", role: .destructive) {
                    clearVehicle = vehicle
                }
            } label: {
                vehicleTile(vehicle, recorded: true)
            }
            .disabled(parking.isLocating)
        } else {
            Button {
                Task { await recordParking(vehicle) }
            } label: {
                vehicleTile(vehicle, recorded: false)
            }
            .disabled(parking.isLocating)
        }
    }

    /// 小圓角正方形：未記錄 = 毛玻璃底 + 彩色圖示；已記錄 = 彩色底 + 白色圖示 + 綠勾勾
    private func vehicleTile(_ vehicle: VehicleType, recorded: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if parking.locatingVehicle == vehicle {
                    ProgressView()
                        .tint(recorded ? .white : vehicle.color)
                } else {
                    Image(systemName: vehicle.icon)
                        .font(.system(size: 20, weight: .semibold))
                }
            }
            .foregroundStyle(recorded ? Color.white : vehicle.color)
            .frame(width: 50, height: 50)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(recorded ? AnyShapeStyle(vehicle.color) : AnyShapeStyle(.regularMaterial))
            }
            .shadow(color: .black.opacity(0.15), radius: 6, y: 3)

            if recorded {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white, .green)
                    .offset(x: 5, y: -5)
            }
        }
        .accessibilityLabel(recorded ? "\(vehicle.name)停車位置選單" : "記錄\(vehicle.name)停車位置")
    }

    private func menuTitle(_ vehicle: VehicleType, _ spot: ParkingSpot) -> String {
        let title = spot.note.isEmpty ? "我的\(vehicle.name)" : spot.note
        let time = spot.savedAt.formatted(.dateTime.month().day().hour().minute())
        let precision = spot.wasAdjusted
            ? "已手動調整"
            : "誤差約 \(Int(spot.accuracy.rounded())) 公尺"
        return "\(title)・\(time) 停・\(precision)"
    }

    // MARK: - 拖曳調整 UI

    /// 圖釘尖端剛好對準地圖中心
    private func centerPin(_ vehicle: VehicleType) -> some View {
        ZStack {
            // 地上的小影子，標示真正的落點
            Ellipse()
                .fill(.black.opacity(0.3))
                .frame(width: 12, height: 6)

            VStack(spacing: 0) {
                Image(systemName: vehicle.icon)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(vehicle.color)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .shadow(radius: 3)
                Rectangle()
                    .fill(vehicle.color)
                    .frame(width: 3, height: 14)
            }
            .offset(y: -29)   // (44 + 14) / 2：讓圖釘底部落在中心點
        }
        .allowsHitTesting(false)   // 不擋住地圖拖曳
    }

    private func adjustBar(_ vehicle: VehicleType) -> some View {
        VStack(spacing: 12) {
            Text("拖曳地圖，讓\(vehicle.name)圖釘對準你的停車格")
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                Button {
                    cancelAdjusting()
                } label: {
                    Text("取消").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    confirmAdjusting(vehicle)
                } label: {
                    Text("確認位置").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(vehicle.color)
            }
            .controlSize(.large)
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - 停車動作

    private func recordParking(_ vehicle: VehicleType) async {
        let ok = await parking.recordCurrentLocation(for: vehicle)
        guard ok else { return }
        goToParking(vehicle)
        await promptNote(for: vehicle, suggest: true)
    }

    private func refineParking(_ vehicle: VehicleType) async {
        switch await parking.refineLocation(for: vehicle) {
        case .refined(let old, let new):
            goToParking(vehicle)
            if new < old - 0.5 {
                showToast("已校正，誤差約 \(Int(old.rounded())) → \(Int(new.rounded())) 公尺")
            } else {
                showToast("已校正，位置已經很準了")
            }
        case .farAway(let distance, let location):
            movePrompt = MovePrompt(vehicle: vehicle, distance: distance, location: location)
        case .failed:
            break   // 錯誤訊息由「無法取得位置」alert 顯示
        }
    }

    /// 開備註框；suggest = true 時先依附近地點預填（使用者仍需按「儲存」）
    private func promptNote(for vehicle: VehicleType, suggest: Bool) async {
        guard let spot = parking.spot(for: vehicle) else { return }
        noteDraft = spot.note
        noteIsSuggested = false

        if suggest {
            showToast("正在找附近地點…")
            if let name = await ParkingNameSuggester.suggest(for: spot.coordinate) {
                noteDraft = name
                noteIsSuggested = true
            }
            hideToast()
        }
        noteVehicle = vehicle
    }

    private func startAdjusting(_ vehicle: VehicleType) {
        guard let spot = parking.spot(for: vehicle) else { return }
        adjustCenter = spot.coordinate
        selectedCampus = Campus.nearest(to: spot.coordinate)
        withAnimation(.spring(duration: 0.4)) {
            adjustingVehicle = vehicle
            // 拉近一點，方便對準停車格
            position = .region(MKCoordinateRegion(
                center: spot.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.0006, longitudeDelta: 0.0006)
            ))
        }
    }

    private func confirmAdjusting(_ vehicle: VehicleType) {
        if let center = adjustCenter {
            parking.setManualLocation(center, for: vehicle)
            showToast("已更新\(vehicle.name)位置")
        }
        withAnimation { adjustingVehicle = nil }
    }

    private func cancelAdjusting() {
        withAnimation { adjustingVehicle = nil }
    }

    private func goToParking(_ vehicle: VehicleType) {
        guard let spot = parking.spot(for: vehicle) else { return }
        withAnimation(.spring(duration: 0.4)) {
            selectedCampus = Campus.nearest(to: spot.coordinate)
            position = .region(MKCoordinateRegion(
                center: spot.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.0015, longitudeDelta: 0.0015)
            ))
        }
    }

    // MARK: - 小提示

    private func showToast(_ message: String) {
        toastTask?.cancel()
        withAnimation(.spring(duration: 0.3)) { toastMessage = message }
        toastTask = Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(duration: 0.3)) { toastMessage = nil }
        }
    }

    private func hideToast() {
        toastTask?.cancel()
        withAnimation(.spring(duration: 0.3)) { toastMessage = nil }
    }

    // MARK: - 輔助

    /// 把 Optional state 轉成 alert / dialog 要的 Bool binding
    private func isPresent<T>(_ value: Binding<T?>) -> Binding<Bool> {
        Binding(
            get: { value.wrappedValue != nil },
            set: { if !$0 { value.wrappedValue = nil } }
        )
    }

    private var parkingErrorBinding: Binding<Bool> {
        Binding(
            get: { parking.errorMessage != nil },
            set: { if !$0 { parking.errorMessage = nil } }
        )
    }

    // MARK: - 搜尋函式
    func performSearch(_ query: String) -> [RoomResult] {
        guard !query.isEmpty else { return [] }
        var results: [RoomResult] = []

        for campus in Campus.allCases {
            for building in campus.buildings {
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
