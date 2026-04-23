//
//  About.swift
//  CollegeApp
//
//  Created by Wesley Wang on 2026/3/20.
//

import SwiftUI

struct AboutView: View {
    
    var body: some View {
        NavigationStack {
            List {
               // 開發者資訊
                Section("關於開發者") {
                    Link(destination: URL(string: "https://github.com/wangwesley1125")!) {
                            HStack {
                                Image(systemName: "person.fill")
                                Text("作者")
                            }
                            .foregroundColor(.teal)
                        }
                }
                
                // 關於此 App
                Section("關於 NKUST plus") {
                    
                    HStack {
                        Text("版本資訊")
                        Spacer()
                        Text("1.3.5")
                    }
                    .foregroundColor(.teal)
                    
                    Link(destination: URL(string: "https://github.com/wangwesley1125/CollegeApp-NKUST")!) {
                        HStack {
                            Text("開源專案")
                        }
                        .foregroundColor(.teal)
                    }
                    
                    NavigationLink {
                        PrivacyView()
                    } label: {
                        HStack {
                            Text("隱私政策")
                        }
                        .foregroundColor(.teal)
                    }
                    
                    NavigationLink {
                        CopyRightView()
                    } label: {
                        HStack {
                            Text("版權聲明")
                        }
                        .foregroundColor(.teal)
                    }
                    
                    Link(destination: URL(string: "mailto:nkustplus@gmail.com?subject=問題回報")!) {
                        HStack {
                            Text("問題回報")
                        }
                        .foregroundColor(.teal)
                    }
                    
                    Button {
                        let appURL = URL(string: "https://apps.apple.com/tw/app/%E9%AB%98%E7%A7%91-plus/id6760967835")!
                        let activityVC = UIActivityViewController(
                            activityItems: ["推薦你使用 NKUST plus！", appURL],
                            applicationActivities: nil
                        )
                        
                        // 取得目前的 UIWindow 來呈現
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = windowScene.windows.first {
                            window.rootViewController?.present(activityVC, animated: true)
                        }
                    } label: {
                        HStack {
                            Text("分享此 App")
                        }
                        .foregroundColor(.teal)
                    }
                    
                    Link(destination: URL(string: "https://www.instagram.com/nkust_plus?igsh=MXR0NXR3MmJiczAybg%3D%3D&utm_source=qr")!) {
                        HStack {
                            Text("追蹤高科 Plus")
                        }
                        .foregroundColor(.teal)
                    }
                    
                }
                
                // 高科大學生專區
                Section("學生專區") {
                    
                    Link(destination: URL(string: "https://enterschool.nkust.edu.tw/")!) {
                        Text("新生專區")
                    }
                    .foregroundColor(.teal)
                    
                    Link(destination: URL(string: "https://elearning.nkust.edu.tw/moocs/#/home")!) {
                        Text("Elearnring 教學平台")
                    }
                    .foregroundColor(.teal)
                    
                    Link(destination: URL(string: "https://ceq.nkust.edu.tw/Home")!) {
                        Text("教學意見調查系統")
                    }
                    .foregroundColor(.teal)
                    
                    Link(destination: URL(string: "https://ws1.nkust.edu.tw/Activity/")!) {
                        Text("活動訊息平台")
                    }
                    .foregroundColor(.teal)
                    
                }
                
                // 關於高科大
                Section("關於高雄科技大學") {
                    
                    Link(destination: URL(string: "https://www.nkust.edu.tw/")!) {
                        Text("國立高雄科技大學官網")
                    }
                    .foregroundColor(.teal)
                    
                    Link(destination: URL(string: "https://acad.nkust.edu.tw/")!) {
                        Text("教務處")
                    }
                    .foregroundColor(.teal)
                    
                    Link(destination: URL(string: "https://osa.nkust.edu.tw/")!) {
                        Text("學務處")
                    }
                    .foregroundColor(.teal)
                    
                    Link(destination: URL(string: "https://gen.nkust.edu.tw/")!) {
                        Text("總務處")
                    }
                    .foregroundColor(.teal)
                    
                    Link(destination: URL(string: "https://oia.nkust.edu.tw/")!) {
                        Text("國際事務處")
                    }
                    .foregroundColor(.teal)
                    
                    Link(destination: URL(string: "https://oosaf.nkust.edu.tw/")!) {
                        Text("學務資訊系統（請假 / 曠課 / 講懲 / 幹部...）")
                    }
                    .foregroundColor(.teal)
                    
                    Link(destination: URL(string: "https://www.lib.nkust.edu.tw/portal/")!) {
                        Text("國立高雄科技大學 圖書館")
                    }
                    .foregroundColor(.teal)
                    
                    
                    Link(destination: URL(string: "https://www.nkust.edu.tw/p/412-1000-85.php")!) {
                        Text("其他行政單位")
                    }
                    .foregroundColor(.teal)
                    
                }
                
            }
                .navigationTitle("關於")
                .navigationBarTitleDisplayMode(.inline)
        }
        
    }
}

#Preview {
    AboutView()
}
