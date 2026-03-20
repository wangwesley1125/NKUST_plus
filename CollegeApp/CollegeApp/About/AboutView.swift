//
//  About.swift
//  CollegeApp
//
//  Created by 王耀偉 on 2026/3/20.
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
                    
                    Section {
                        HStack {
                            Text("版本資訊")
                            Spacer()
                            Text("1.0")
                        }
                    }
                    .foregroundColor(.teal)
                    
                    Section {
                        Link(destination: URL(string: "https://github.com/wangwesley1125/CollegeApp-NKUST")!) {
                                HStack {
                                    Text("開源專案")
                                }
                                .foregroundColor(.teal)
                            }
                    }
                    
                    Section {
                        NavigationLink {
                            PrivacyView()
                        } label: {
                            HStack {
                                Text("隱私政策")
                            }
                            .foregroundColor(.teal)
                        }
                    }
                    
                    Section {
                        NavigationLink {
                            CopyRightView()
                        } label: {
                            HStack {
                                Text("版權聲明")
                            }
                            .foregroundColor(.teal)
                        }
                    }
                    
                    Section {
                        Link(destination: URL(string: "mailto:nkustplus@gmail.com?subject=問題回報")!) {
                                HStack {
                                    Text("問題回報")
                                }
                                .foregroundColor(.teal)
                            }
                    }
                    
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
