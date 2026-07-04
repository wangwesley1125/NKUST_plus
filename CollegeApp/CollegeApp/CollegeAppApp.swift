//
//  CollegeAppApp.swift
//  CollegeApp
//
//  Created by Wesley Wang on 2026/3/11.
//

import SwiftUI

@main
struct CollegeAppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var newAppVersion: String? = nil
    
    // 防止重複觸發
    @State private var isCheckingVersion = false

    var body: some Scene {
        WindowGroup {
            LoginView()
                .task {
                    await checkForUpdate() // 冷啟動時也會執行
                }
                .alert("發現新版本 🎉", isPresented: Binding(
                    get: { newAppVersion != nil },
                    set: { if !$0 { newAppVersion = nil } }
                )) {
                    Button("前往更新") {
                        if let url = URL(string: "itms-apps://apps.apple.com/app/id6760967835") {
                            UIApplication.shared.open(url)
                        }
                        newAppVersion = nil
                    }
                    Button("稍後再說", role: .cancel) {
                        newAppVersion = nil
                    }
                } message: {
                    if let v = newAppVersion {
                        Text("新版本 \(v) 已上架，建議更新以獲得最佳體驗。")
                    }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await checkForUpdate() }
            }
        }
    }
    
    private func checkForUpdate() async {
        guard !isCheckingVersion else { return }   // 避免 .task 跟 onChange 同時觸發打兩次 API
        isCheckingVersion = true
        newAppVersion = await AppUpdateChecker.check()
        isCheckingVersion = false
    }
}
