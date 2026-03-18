//
//  AllCampus.swift
//  CollegeApp
//
//  Created by 王耀偉 on 2026/3/15.
//

import SwiftUI

enum Campus: String, CaseIterable {
    case jiangong = "建工"
    case yanchao = "燕巢"
    case diyi = "第一"
    case qijin = "旗津"
    case nanzi = "楠梓"
}

struct AllCampusView: View {
    @State private var selectedCampus: Campus = .jiangong

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 頂部校區選擇
                ScrollView(.horizontal, showsIndicators: false) {
                    Picker("校區", selection: $selectedCampus) {
                        ForEach(Campus.allCases, id: \.self) { campus in
                            Text(campus.rawValue).tag(campus)
                        }
                    }
                    .pickerStyle(.palette)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(.bar)
                

                Divider()

                // 根據選擇顯示對應校區地圖
                switch selectedCampus {
                case .jiangong:
                    JiangongMapView()
                case .yanchao:
                    YanchaoMapView()
                case .diyi:
                    DiyiMapView()
                case .qijin:
                    QijinMapView()
                case .nanzi:
                    NanziMapView()
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
