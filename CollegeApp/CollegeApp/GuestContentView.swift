//
//  GuestContentView.swift
//  CollegeApp
//
//  Created by 王耀偉 on 2026/3/31.
//

import SwiftUI

struct GuestContentView: View {
    
    var isGuest: Binding<Bool>? = nil
    
    var body: some View {
        TabView {
            CalendarView(isGuest: isGuest)
                .tabItem {
                    Label("行事曆", systemImage: "calendar")
                }
            
            AllCampusView()
                .tabItem {
                    Label("校園地圖", systemImage: "map")
                }
            
            AboutView()
                .tabItem {
                    Label("關於", systemImage: "info.circle")
                }
        }
        .tint(Color(Color.teal))
    }
}

#Preview {
    GuestContentView(isGuest: .constant(true))
}
