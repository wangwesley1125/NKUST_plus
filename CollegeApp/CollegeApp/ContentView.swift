//
//  ContentView.swift
//  CollegeApp
//
//  Created by Wesley Wang on 2026/3/13.
//

import SwiftUI

struct ContentView: View {
    
    let cookies: [HTTPCookie]
    @Binding var isLoggedIn: Bool
    
    var body: some View {
        TabView {
            
            // 首頁
            MainView(isLoggedIn: $isLoggedIn, cookies: cookies)
                .tabItem {
                    Image(systemName: "house")
                    Text("首頁")
                }
            
            // 課表
            CourseView(cookies: cookies)
                .tabItem {
                    Image(systemName: "calendar")
                    Text("個人課表")
                }
            // 成績
            ScoreView(cookies: cookies)
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("歷年成績")
                }
            
            // 校園地圖
            AllCampusView()
                .tabItem {
                    Image(systemName: "map")
                    Text("校園地圖")
                }
            
            // 設定
//            SettingView(isLoggedIn: $isLoggedIn, cookies: cookies)
//                .tabItem {
//                    Image(systemName: "person.fill")
//                    Text("個人")
//                }
            
            // 關於
            AboutView()
                .tabItem {
                    Image(systemName: "info.square")
                    Text("關於")
                }
            
        }
        .tint(Color(Color.teal))
    }
}

#Preview {
    ContentView(cookies: [], isLoggedIn: .constant(true))
}
