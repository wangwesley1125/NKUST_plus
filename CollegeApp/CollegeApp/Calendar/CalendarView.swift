//
//  CalendarView.swift
//  CollegeApp
//
//  Created by Wesley Wang on 2026/3/18.
//

import SwiftUI
import PDFKit
 
// MARK: - 資料模型
 
/// CSV 裡的一列：學年度分類 / 中英文分類 / 檔名 / PDF 完整網址
private struct CalendarItem {
    let group: String      // 例："115學年度"
    let subgroup: String   // 例："中文版" 或 "English Version"
    let filename: String   // 例："115學年度第1學期行事曆 (NEW!!)"
    let url: String        // 完整 PDF 網址（或相對路徑）
}
 
/// 一個學年度底下的兩個學期 PDF
private struct YearCalendar: Identifiable {
    let id: Int // 學年度，例如 115
    var semester1: PDFDocument?
    var semester2: PDFDocument?
}
 
struct CalendarView: View {
    // 依學年度由新到舊排序的清單，例如 [115學年度, 114學年度, ...]
    // 完全依照 CSV 裡實際出現的學年度動態產生，不寫死「目前 + 下一學年」
    @State private var yearCalendars: [YearCalendar] = []
    // 目前選到的分頁，用 year * 10 + semester 編碼，例如 115-1 → 1151
    @State private var selectedTag: Int = 0
    @State private var isLoading = true
    @State private var errorMessage: String?
    var isGuest: Binding<Bool>? = nil // 如果使用者是訪客會出現登入按鈕，有登入過就不會出現
 
    // 學校頁面內嵌的 Google 試算表 (CSV 匯出) 網址
    // 若這份試算表未來換掉，只要更新這個網址即可，不需要再改解析邏輯
    private let sheetURLString = "https://docs.google.com/spreadsheets/d/e/2PACX-1vSgjFXXnuyCosq2gWkvldnFtNPQl8mDU1d13UVIOx_IInPPeSsTXDUlTThakD_NAZKhM16O_1TwgOlT/pub?gid=1497644044&single=true&output=csv"
 
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("載入行事曆中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("重試") { Task { await loadCalendar() } }
                            .buttonStyle(.borderedProminent)
                            .tint(.teal)
                    }
                    .padding()
                } else {
                    VStack(spacing: 0) {
                        // 學期切換 Picker：依 CSV 實際擁有的學年度 x 學期 動態產生分頁
                        Picker("學期", selection: $selectedTag) {
                            ForEach(yearCalendars) { yc in
                                if yc.semester1 != nil {
                                    Text("\(yc.id)-1").tag(yc.id * 10 + 1)
                                }
                                if yc.semester2 != nil {
                                    Text("\(yc.id)-2").tag(yc.id * 10 + 2)
                                }
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding()
 
                        // 對應 PDF
                        if let doc = currentDocument() {
                            PDFKitView(document: doc)
                                .ignoresSafeArea(edges: .bottom)
                        } else {
                            ProgressView("載入中...").frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
            .navigationTitle("行事曆")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadCalendar() }
            .toolbar {
                if let isGuest = isGuest {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("\(Image(systemName: "person.fill"))登入") {
                            UserDefaults.standard.set(false, forKey: "isGuest")
                            isGuest.wrappedValue = false
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .background(Color.blue)
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }
 
    /// 依 selectedTag（year * 10 + semester）找出對應要顯示的 PDFDocument
    private func currentDocument() -> PDFDocument? {
        let year = selectedTag / 10
        let semester = selectedTag % 10
        guard let yc = yearCalendars.first(where: { $0.id == year }) else { return nil }
        return semester == 1 ? yc.semester1 : yc.semester2
    }
 
    // MARK: - 主要載入流程
 
    func loadCalendar() async {
        isLoading = true
        errorMessage = nil
 
        do {
            guard let sheetURL = URL(string: sheetURLString) else {
                throw URLError(.badURL)
            }
 
            // 注意：這裡刻意不設定手機版 User-Agent。
            // Google 試算表對手機版 Safari 的 UA 常會回傳「要不要用 App 開啟」的提示頁，
            // 而不是純 CSV 內容，導致抓回來的資料是空的或格式不對（parseCSV 會得到 0 筆）。
            // 保留 URLSession 預設的 UA（或用桌機版 UA），讓伺服器乖乖回傳原始 CSV。
            let request = URLRequest(url: sheetURL)
 
            let (data, response) = try await URLSession.shared.data(for: request)
 
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                throw URLError(.badServerResponse)
            }
 
            guard let csv = String(data: data, encoding: .utf8) else {
                throw URLError(.cannotDecodeContentData)
            }
 
            print("📄 收到的原始內容長度：\(data.count) bytes，前 200 字元預覽：\n\(csv.prefix(200))")
 
            let items = Self.parseCSV(csv)
            print("📄 CSV 解析出 \(items.count) 筆資料")
            guard !items.isEmpty else {
                throw URLError(.zeroByteResource)
            }
 
            // 找出 CSV 裡「實際出現」的所有學年度（例如 "115學年度"、"114學年度"...），
            // 由大到小排序 —— 完全依資料而定，不假設一定有「下一學年」
            let years: [Int] = Array(Set(items.compactMap { item -> Int? in
                Self.extractYear(from: item.group)
            })).sorted(by: >)
            print("📅 找到學年度：\(years)")
 
            guard !years.isEmpty else {
                throw URLError(.cannotParseResponse)
            }
 
            // 只取「中文版」，並依檔名判斷是第1學期還是第2學期
            func matchedURL(forYear year: Int, semester: Int) -> String? {
                let groupName = "\(year)學年度"
                return items.first(where: {
                    $0.group == groupName &&
                    $0.subgroup.contains("中文") &&
                    $0.filename.contains("第\(semester)學期")
                })?.url
            }
 
            // 同時下載「每個學年度 x 每個學期」的 PDF
            let results: [(year: Int, semester: Int, doc: PDFDocument?)] = await withTaskGroup(
                of: (Int, Int, PDFDocument?).self
            ) { group in
                for year in years {
                    for semester in [1, 2] {
                        group.addTask {
                            guard let urlString = await matchedURL(forYear: year, semester: semester) else {
                                return (year, semester, nil)
                            }
                            let doc = await self.fetchPDF(from: urlString)
                            return (year, semester, doc)
                        }
                    }
                }
                var collected: [(Int, Int, PDFDocument?)] = []
                for await result in group {
                    collected.append(result)
                }
                return collected
            }
 
            var built: [Int: YearCalendar] = [:]
            for year in years {
                built[year] = YearCalendar(id: year, semester1: nil, semester2: nil)
            }
            for (year, semester, doc) in results {
                if semester == 1 {
                    built[year]?.semester1 = doc
                } else {
                    built[year]?.semester2 = doc
                }
            }
 
            let sortedCalendars = years.compactMap { built[$0] }
            yearCalendars = sortedCalendars
 
            print("📚 下載結果：" + sortedCalendars.map {
                "\($0.id)-1=\($0.semester1 != nil), \($0.id)-2=\($0.semester2 != nil)"
            }.joined(separator: ", "))
 
            // 預設選到「第一個有資料的學期」（最新學年度優先）
            guard let firstAvailable = sortedCalendars.first(where: { $0.semester1 != nil || $0.semester2 != nil }) else {
                throw URLError(.cannotParseResponse)
            }
            if firstAvailable.semester1 != nil {
                selectedTag = firstAvailable.id * 10 + 1
            } else {
                selectedTag = firstAvailable.id * 10 + 2
            }
 
        } catch {
            errorMessage = "無法取得行事曆，請稍後再試"
            print("行事曆載入失敗：\(error)")
        }
 
        isLoading = false
    }
 
    /// 學校網站的網域，CSV 裡的 URL 欄位常常只是相對路徑（例如 "/var/file/.../cal115-1.pdf"），
    /// 需要補上這個網域才會是可以下載的完整網址
    private static let schoolBaseURL = "https://acad.nkust.edu.tw"
 
    /// 把 CSV 裡的 URL 欄位轉成可以直接下載的完整網址。
    /// 如果本來就是完整網址（開頭是 http/https）就原樣使用；
    /// 如果是以 "/" 開頭的相對路徑，就補上學校網域。
    private static func absoluteURLString(from raw: String) -> String {
        if raw.lowercased().hasPrefix("http://") || raw.lowercased().hasPrefix("https://") {
            return raw
        }
        if raw.hasPrefix("/") {
            return schoolBaseURL + raw
        }
        return schoolBaseURL + "/" + raw
    }
 
    /// 下載指定網址的 PDF，失敗回傳 nil（不 throw，讓某一學期抓不到不影響其他學期）
    /// 註：學校網站對非瀏覽器的請求似乎有防護機制（robots.txt 明確禁止自動化存取），
    /// 所以這裡補齊一組接近真實瀏覽器的 headers，並且不再用 try? 吞掉錯誤，
    /// 改成印出詳細狀態，方便在 Xcode console 判斷到底是哪一種失敗（403 / timeout / 資料格式錯誤...）。
    func fetchPDF(from urlString: String) async -> PDFDocument? {
        let fullURLString = Self.absoluteURLString(from: urlString)
        guard let url = URL(string: fullURLString), url.scheme != nil, url.host != nil else {
            print("⚠️ fetchPDF: 無效網址 \(urlString)")
            return nil
        }
 
        var request = URLRequest(url: url)
        request.setValue("https://acad.nkust.edu.tw/p/426-1063-6.php?Lang=zh-tw", forHTTPHeaderField: "Referer")
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("application/pdf,*/*", forHTTPHeaderField: "Accept")
 
        do {
            let (pdfData, response) = try await URLSession.shared.data(for: request)
 
            guard let httpResponse = response as? HTTPURLResponse else {
                print("⚠️ fetchPDF: 沒有 HTTPURLResponse，url=\(url)")
                return nil
            }
 
            guard httpResponse.statusCode == 200 else {
                print("⚠️ fetchPDF: 伺服器回傳狀態碼 \(httpResponse.statusCode)，url=\(url)")
                return nil
            }
 
            guard let document = PDFDocument(data: pdfData) else {
                print("⚠️ fetchPDF: 回傳的資料不是有效 PDF（可能是驗證頁面或錯誤頁面），bytes=\(pdfData.count)，url=\(url)")
                return nil
            }
 
            return document
        } catch {
            print("⚠️ fetchPDF: 下載失敗 \(error)，url=\(url)")
            return nil
        }
    }
 
    // MARK: - CSV 解析
 
    /// 簡單但穩健的 CSV parser，支援欄位用雙引號包住、內含逗號或換行的情況
    private static func parseCSV(_ csv: String) -> [CalendarItem] {
        let rows = parseCSVRows(csv)
        guard rows.count > 1 else { return [] } // 第一列是標題，跳過
 
        var items: [CalendarItem] = []
        for row in rows.dropFirst() {
            guard row.count >= 4 else { continue }
            let group = row[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let subgroup = row[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let filename = row[2].trimmingCharacters(in: .whitespacesAndNewlines)
            let url = row[3].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !group.isEmpty, !url.isEmpty else { continue }
            items.append(CalendarItem(group: group, subgroup: subgroup, filename: filename, url: url))
        }
        return items
    }
 
    /// 逐字元解析 CSV，正確處理雙引號欄位（"..."）與其中的逗號 / 換行 / 跳脫的雙引號 ("")
    ///
    /// 重要：Swift 的 String 是以「grapheme cluster」為單位的 Character 序列，
    /// 而 "\r\n"（Windows 風格換行，Google 試算表匯出 CSV 常用這種）在 Swift 裡
    /// 會被視為「同一個 Character」，不是兩個獨立的 "\r" 和 "\n"！
    /// 如果直接在 switch 裡分別比對 "\n" 和 "\r"，遇到 "\r\n" 這個組合字元時兩個 case
    /// 都比對不到，整份 CSV 就會被誤判成沒有換行、變成一整個欄位。
    /// 所以先把所有換行符號正規化成單純的 "\n"，再逐字元解析，就不會有這個問題。
    private static func parseCSVRows(_ csv: String) -> [[String]] {
        let normalized = csv
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
 
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var insideQuotes = false
 
        let chars = Array(normalized)
        var i = 0
        while i < chars.count {
            let c = chars[i]
 
            if insideQuotes {
                if c == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" {
                        currentField.append("\"") // 跳脫的雙引號
                        i += 1
                    } else {
                        insideQuotes = false
                    }
                } else {
                    currentField.append(c)
                }
            } else {
                switch c {
                case "\"":
                    insideQuotes = true
                case ",":
                    currentRow.append(currentField)
                    currentField = ""
                case "\n":
                    currentRow.append(currentField)
                    rows.append(currentRow)
                    currentRow = []
                    currentField = ""
                default:
                    currentField.append(c)
                }
            }
            i += 1
        }
 
        // 最後一列（檔案結尾若沒有換行）
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }
 
        return rows
    }
 
    /// 從 "115學年度" 這種字串裡取出數字 115
    private static func extractYear(from group: String) -> Int? {
        let digits = group.prefix { $0.isNumber }
        return Int(digits)
    }
}
 
#Preview {
    CalendarView()
}
