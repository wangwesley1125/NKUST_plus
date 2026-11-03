//
//  ParkingStore.swift
//  CollegeApp
//
//  記錄停車位置（機車 / 汽車各一筆）
//  - 記錄：取得目前定位 → 存在本機 UserDefaults
//  - GPS 校正：在車旁再定位一次，與舊點依準度加權平均（越按越準）
//  - 手動調整：使用者在地圖上拖曳到正確停車格
//  - 自動命名：依附近停車場 / 校區建築 / 路名產生備註建議
//

import SwiftUI
import CoreLocation
import MapKit
import Observation

// MARK: - 車種

enum VehicleType: String, CaseIterable, Codable, Identifiable {
    case scooter
    case car

    var id: String { rawValue }

    var name: String {
        switch self {
        case .scooter: return "機車"
        case .car:     return "汽車"
        }
    }

    var icon: String {
        switch self {
        case .scooter: return "motorcycle.fill"
        case .car:     return "car.fill"
        }
    }

    var color: Color {
        switch self {
        case .scooter: return .orange
        case .car:     return .blue
        }
    }
}

// MARK: - 停車位置 Model

struct ParkingSpot: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    /// 定位誤差（公尺）
    var accuracy: Double
    var savedAt: Date
    /// 使用者備註，例如「燕巢 B 停車場第 3 排」
    var note: String
    /// 是否由使用者手動拖曳調整過（Optional：舊資料沒有這個欄位也能讀）
    var isAdjusted: Bool? = nil

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var wasAdjusted: Bool { isAdjusted == true }
}

// MARK: - GPS 校正結果

enum RefineResult {
    /// 已與舊點合併
    case refined(oldAccuracy: Double, newAccuracy: Double)
    /// 目前位置離停車點太遠（人可能已經離開），交給 UI 詢問
    case farAway(distance: Double, location: CLLocation)
    /// 定位失敗（錯誤訊息已寫在 errorMessage）
    case failed
}

// MARK: - 停車位置管理（定位 + 本機儲存）

@MainActor
@Observable
final class ParkingStore: NSObject {
    private static let keyPrefix = "savedParkingSpot."
    /// 舊版（只有機車）用的 key，啟動時自動搬到機車
    private static let legacyKey = "savedParkingSpot"

    private(set) var spots: [VehicleType: ParkingSpot] = [:]
    /// 正在定位哪一台車（nil = 沒在定位）
    private(set) var locatingVehicle: VehicleType?
    var errorMessage: String?
    /// 定位權限被拒，UI 可據此顯示「前往設定」
    private(set) var isPermissionDenied = false

    var isLocating: Bool { locatingVehicle != nil }

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var bestLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        Self.migrateLegacyIfNeeded()
        for vehicle in VehicleType.allCases {
            spots[vehicle] = Self.load(vehicle)
        }
    }

    func spot(for vehicle: VehicleType) -> ParkingSpot? {
        spots[vehicle]
    }

    // MARK: 記錄目前位置

    /// 取得目前位置並存成該車種的停車位置（覆蓋舊的）。成功回傳 true。
    @discardableResult
    func recordCurrentLocation(for vehicle: VehicleType) async -> Bool {
        guard let loc = await acquireLocation(for: vehicle) else { return false }
        replace(with: loc, for: vehicle)
        return true
    }

    /// 用指定的定位結果取代停車位置（新的一次停車，備註清空）
    func replace(with location: CLLocation, for vehicle: VehicleType) {
        spots[vehicle] = ParkingSpot(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracy: location.horizontalAccuracy,
            savedAt: .now,
            note: ""
        )
        persist(vehicle)
    }

    // MARK: GPS 校正

    /// 在車旁再定位一次，與舊點依準度加權平均。
    /// 誤差越小的那筆權重越大（權重 = 1 / 誤差²），所以多校正幾次會越來越準。
    func refineLocation(for vehicle: VehicleType) async -> RefineResult {
        guard let old = spots[vehicle] else { return .failed }
        guard let loc = await acquireLocation(for: vehicle) else { return .failed }

        let oldLoc = CLLocation(latitude: old.latitude, longitude: old.longitude)
        let distance = loc.distance(from: oldLoc)

        // 兩個誤差圈有重疊（或 30 公尺內）才合併；否則人大概已經離開車子了
        let threshold = max(30, old.accuracy + loc.horizontalAccuracy)
        guard distance <= threshold else {
            return .farAway(distance: distance, location: loc)
        }

        let w1 = 1 / pow(max(old.accuracy, 1), 2)
        let w2 = 1 / pow(max(loc.horizontalAccuracy, 1), 2)

        var merged = old
        merged.latitude  = (old.latitude  * w1 + loc.coordinate.latitude  * w2) / (w1 + w2)
        merged.longitude = (old.longitude * w1 + loc.coordinate.longitude * w2) / (w1 + w2)
        // 理論誤差會變小，但短時間內的 GPS 誤差彼此相關，不會真的無限變準，
        // 所以最低只顯示到 3 公尺
        merged.accuracy = max(1 / sqrt(w1 + w2), 3)
        // 停車時間、備註維持原本的

        spots[vehicle] = merged
        persist(vehicle)
        return .refined(oldAccuracy: old.accuracy, newAccuracy: merged.accuracy)
    }

    // MARK: 手動調整

    /// 使用者在地圖上拖曳後確認的位置。保留停車時間與備註。
    func setManualLocation(_ coordinate: CLLocationCoordinate2D, for vehicle: VehicleType) {
        guard var s = spots[vehicle] else { return }
        s.latitude = coordinate.latitude
        s.longitude = coordinate.longitude
        s.accuracy = 0
        s.isAdjusted = true
        spots[vehicle] = s
        persist(vehicle)
    }

    // MARK: 備註 / 清除

    func updateNote(_ note: String, for vehicle: VehicleType) {
        guard var s = spots[vehicle] else { return }
        s.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        spots[vehicle] = s
        persist(vehicle)
    }

    func clear(_ vehicle: VehicleType) {
        spots[vehicle] = nil
        UserDefaults.standard.removeObject(forKey: Self.key(for: vehicle))
    }

    // MARK: 用 Apple 地圖步行導航

    func openWalkingDirections(for vehicle: VehicleType) {
        guard let spot = spots[vehicle] else { return }
        let item: MKMapItem
        if #available(iOS 26.0, *) {
            item = MKMapItem(
                location: CLLocation(latitude: spot.latitude, longitude: spot.longitude),
                address: nil
            )
        } else {
            item = MKMapItem(placemark: MKPlacemark(coordinate: spot.coordinate))
        }
        item.name = spot.note.isEmpty ? "我的\(vehicle.name)" : spot.note
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }

    // MARK: 定位（共用）

    /// 取得一筆目前位置：最多等約 10 秒，精度到 15 公尺內就提早結束。
    /// 失敗時回傳 nil，並把原因寫進 errorMessage。
    private func acquireLocation(for vehicle: VehicleType) async -> CLLocation? {
        guard !isLocating else { return nil }   // 一次只定位一台
        errorMessage = nil
        isPermissionDenied = false

        switch manager.authorizationStatus {
        case .denied, .restricted:
            markPermissionDenied()
            return nil
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            break
        }

        locatingVehicle = vehicle
        bestLocation = nil
        manager.startUpdatingLocation()

        // GPS 剛啟動的前幾筆通常誤差很大，多等一下會準很多
        for _ in 0..<20 {
            try? await Task.sleep(for: .milliseconds(500))
            if isPermissionDenied { break }
            if let loc = bestLocation, loc.horizontalAccuracy <= 15 { break }
        }

        manager.stopUpdatingLocation()
        locatingVehicle = nil

        if isPermissionDenied { return nil }

        guard let loc = bestLocation else {
            errorMessage = "目前無法取得位置，請移到較空曠的地方再試一次。"
            return nil
        }
        return loc
    }

    // MARK: 本機儲存

    private static func key(for vehicle: VehicleType) -> String {
        keyPrefix + vehicle.rawValue
    }

    private func persist(_ vehicle: VehicleType) {
        guard let spot = spots[vehicle],
              let data = try? JSONEncoder().encode(spot) else { return }
        UserDefaults.standard.set(data, forKey: Self.key(for: vehicle))
    }

    private static func load(_ vehicle: VehicleType) -> ParkingSpot? {
        guard let data = UserDefaults.standard.data(forKey: key(for: vehicle)) else { return nil }
        return try? JSONDecoder().decode(ParkingSpot.self, from: data)
    }

    /// 上一版只存一筆（機車），搬到新的機車 key
    private static func migrateLegacyIfNeeded() {
        let defaults = UserDefaults.standard
        guard let legacy = defaults.data(forKey: legacyKey) else { return }
        if defaults.data(forKey: key(for: .scooter)) == nil {
            defaults.set(legacy, forKey: key(for: .scooter))
        }
        defaults.removeObject(forKey: legacyKey)
    }

    private func markPermissionDenied() {
        isPermissionDenied = true
        errorMessage = "需要定位權限才能記錄停車位置，請到「設定」開啟。"
    }
}

// MARK: - CLLocationManagerDelegate

extension ParkingStore: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            for loc in locations where loc.horizontalAccuracy >= 0 {
                // 只收最近 10 秒內的位置，避免拿到系統快取的舊位置
                guard abs(loc.timestamp.timeIntervalSinceNow) < 10 else { continue }
                if let best = self.bestLocation, best.horizontalAccuracy <= loc.horizontalAccuracy {
                    continue
                }
                self.bestLocation = loc
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        print("停車定位失敗：\(error)")
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            if self.isLocating, status == .denied || status == .restricted {
                self.markPermissionDenied()
            }
        }
    }
}

// MARK: - 停車地點名稱建議

/// 依序嘗試：
/// 1. Apple 地圖上 80 公尺內的停車場名稱
/// 2. 自己的校區建築資料：150 公尺內最近的建築 →「建工校區・電資大樓旁」
/// 3. 反向地理編碼（路名 / 地點名稱）
/// 最多等 3 秒，找不到就回傳 nil（使用者自己填）
@MainActor
enum ParkingNameSuggester {

    static func suggest(for coordinate: CLLocationCoordinate2D) async -> String? {
        await withTaskGroup(of: String?.self) { group in
            group.addTask { await compute(for: coordinate) }
            group.addTask {
                try? await Task.sleep(for: .seconds(3))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    private static func compute(for coordinate: CLLocationCoordinate2D) async -> String? {
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let campus = Campus.nearest(to: coordinate)
        let campusDistance = CLLocation(latitude: campus.center.latitude,
                                        longitude: campus.center.longitude).distance(from: target)
        // 離校門 1.5 公里內才加校區名稱
        let campusPrefix = campusDistance < 1500 ? "\(campus.rawValue)校區・" : ""

        // 1. Apple 地圖的停車場
        if let lot = await nearbyParkingLot(near: target) {
            return campusPrefix + lot
        }

        // 2. 最近的校區建築
        if campusDistance < 1500,
           let building = nearestBuilding(in: campus, to: target, within: 150) {
            return "\(campusPrefix)\(building)旁"
        }

        // 3. 路名 / 地點名稱
        if let place = await reverseGeocode(target) {
            return "\(campusPrefix)\(place)附近"
        }
        return nil
    }

    private static func nearbyParkingLot(near location: CLLocation) async -> String? {
        let request = MKLocalPointsOfInterestRequest(center: location.coordinate, radius: 80)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.parking])
        guard let response = try? await MKLocalSearch(request: request).start() else { return nil }

        let nearest = response.mapItems.min {
            itemLocation($0).distance(from: location) < itemLocation($1).distance(from: location)
        }
        guard let name = nearest?.name, !name.isEmpty else { return nil }
        return name
    }

    private static func nearestBuilding(in campus: Campus,
                                        to location: CLLocation,
                                        within maxDistance: CLLocationDistance) -> String? {
        let ranked = campus.buildings
            .map { building -> (name: String, distance: CLLocationDistance) in
                let c = building.coordinate
                return (building.name,
                        CLLocation(latitude: c.latitude, longitude: c.longitude).distance(from: location))
            }
            .min { $0.distance < $1.distance }

        guard let ranked, ranked.distance <= maxDistance else { return nil }
        return ranked.name
    }

    private static func reverseGeocode(_ location: CLLocation) async -> String? {
        if #available(iOS 26.0, *) {
            guard let request = MKReverseGeocodingRequest(location: location),
                  let item = try? await request.mapItems.first else { return nil }
            return item.name
        } else {
            guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else { return nil }
            return placemark.name ?? placemark.thoroughfare
        }
    }

    private static func itemLocation(_ item: MKMapItem) -> CLLocation {
        if #available(iOS 26.0, *) {
            return item.location
        } else {
            return item.placemark.location
                ?? CLLocation(latitude: item.placemark.coordinate.latitude,
                              longitude: item.placemark.coordinate.longitude)
        }
    }
}
