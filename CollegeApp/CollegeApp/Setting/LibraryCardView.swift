//
//  LibraryCardView.swift
//  CollegeApp
//
//  Created by WesleyWang on 2026/3/30.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct LibraryCardView: View {
    let studentId: String
    let name: String

    @Environment(\.dismiss) private var dismiss
    @State private var originalBrightness: CGFloat = UIScreen.main.brightness

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // QR Code
                VStack(spacing: 12) {
                    Text("QR Code")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let qrImage = generateQRCode(from: studentId) {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 200, height: 200)
                    }
                }

                // Barcode
                VStack(spacing: 12) {
                    Text("Barcode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let barcodeImage = generateBarcode(from: studentId) {
                        Image(uiImage: barcodeImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 280, height: 100)
                    }
                    Text(studentId)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .kerning(2) // 字之間的距離
                }

                // 姓名
                Text(name)
                    .font(.headline)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding()
            .navigationTitle("圖書館借閱證")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .onAppear {
            originalBrightness = UIScreen.main.brightness
            UIScreen.main.brightness = 1.0
        }
        .onDisappear {
            UIScreen.main.brightness = originalBrightness
        }
    }

    // MARK: - QR Code 產生
    func generateQRCode(from string: String) -> UIImage? {
        // 把學號字串轉成 Data（UTF-8編碼）丟進去
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        
        // 容錯等級，代表就算 QR Code 有 15% 損壞還是能掃出來
        // QR Code 容錯等級 (%:可損壞比例)：
        // "L" 7% -> 乾淨環境、純數位顯示
        // "M" 15% -> 一般用途
        // "Q" 25% -> 容易髒污的環境
        // "H" 30% -> 印刷品、戶外、logo疊加
        filter.correctionLevel = "M"
        
        // 濾鏡產出的 CIImage 原始尺寸很小，用 CGAffineTransform 放大 10 倍，不然顯示出來會很模糊
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - Barcode 產生
    // 和 QR Code 的概念一樣
    // 學校的 Bar Code 是 Code39，我使用的是 Code128
    func generateBarcode(from string: String) -> UIImage? {
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = Data(string.utf8)
        filter.quietSpace = 10
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 3, y: 3))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    LibraryCardView(studentId: "A123456789", name: "王小明")
}
