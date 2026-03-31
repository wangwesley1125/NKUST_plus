//
//  SettingView.swift
//  CollegeApp
//
//  Created by Wesley Wang on 2026/3/14.
//

import SwiftUI

struct SettingView: View {
    @Binding var isLoggedIn: Bool
    let cookies: [HTTPCookie]
    @State private var profileImage: UIImage? = nil
    
    @State private var profile = StudentProfile()
    @State private var isLoading = true
    
    @State private var showLibraryCard = false
    
    // 個人頭像
    func loadPhoto(from urlString: String) async {
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        let cookieHeader = HTTPCookie.requestHeaderFields(with: cookies)
        cookieHeader.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let image = UIImage(data: data) else { return }
        profileImage = image
    }
    
    var body: some View {
        NavigationStack {
            List {
                // 個人資料區塊
                Section {
                    HStack(spacing: 16) {
                        // 照片
                        Group {
                            if let img = profileImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.teal)
                            }
                        }
                        .frame(width: 70, height: 70)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.teal, lineWidth: 2))
                        
                        // 姓名 + 學號
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.name)
                                .font(.title3)
                                .bold()
                            Text(profile.englishName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(profile.studentId)
                                .font(.caption)
                                .foregroundColor(.teal)
                        }
                        
                        Spacer()
                        
                        // QR Code & BarCode
                        Button() {
                            showLibraryCard = true
                        } label: {
                            Image(systemName: "qrcode")
                                .resizable()
                                .frame(width: 50, height: 50)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // 學籍資料
                Section("學籍資料") {
                    profileRow(icon: "building.columns.fill", label: "科系", value: profile.department)
                    profileRow(icon: "person.3.fill", label: "班級", value: profile.className)
                    profileRow(icon: "checkmark.seal.fill", label: "在學狀態", value: profile.status)
//                    NavigationLink {
//                        SchoolSertifacate(cookies: cookies)
//                    } label: {
//                        profileRow(icon: "checkmark.seal.fill", label: "在學狀態", value: profile.status)
//                    }
                }
                
                // 行事曆
                Section {
                    NavigationLink {
                        // CalendarView(isGuest: .constant(true))
                        CalendarView()
                    } label: {
                        HStack {
                            Image(systemName: "calendar")
                            Text("行事曆")
                        }
                        .foregroundColor(.teal)
                    }
                }
                
                // 登出
                Section {
                    Button(role: .destructive) {
                        CookieStorage.clear()
                        isLoggedIn = false
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("登出")
                        }
                    }
                }
            }
            .navigationTitle("個人資料")
            .navigationBarTitleDisplayMode(.inline)
            .redacted(reason: isLoading ? .placeholder : [])
        }
        .task { await loadProfile() }
        .sheet(isPresented: $showLibraryCard) {
            LibraryCardView(
                studentId: profile.studentId,
                name: profile.name
            )
        }
    }
    
    func profileRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.teal)
                .frame(width: 24)
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .bold()
        }
    }
    
    func loadProfile() async {
        do {
            let html = try await ProfileService.shared.fetchProfile(cookies: cookies)
            profile = try ProfileParser.parse(html: html)
            await loadPhoto(from: profile.photoURL)
        } catch {
            print("載入個人資料失敗：\(error)")
        }
        isLoading = false
    }
}

#Preview {
    SettingView(isLoggedIn: .constant(true), cookies: [])
}
