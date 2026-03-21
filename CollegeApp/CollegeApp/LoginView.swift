import SwiftUI
import WebKit

// MARK: - Cookie 持久化工具

struct CookieStorage {
    static let key = "savedCookies"
    
    // 儲存 Cookie
    static func save(_ cookies: [HTTPCookie]) {
        let data = cookies.compactMap { cookie -> [String: Any]? in
            return HTTPCookie.requestHeaderFields(with: [cookie]).isEmpty ? nil : cookie.properties?.reduce(into: [String: Any]()) { result, pair in
                result[pair.key.rawValue] = pair.value
            }
        }
        UserDefaults.standard.set(data, forKey: key)
    }
    
    // 讀取 Cookie
    static func load() -> [HTTPCookie] {
        guard let data = UserDefaults.standard.array(forKey: key) as? [[String: Any]] else { return [] }
        return data.compactMap { dict in
            let properties = dict.reduce(into: [HTTPCookiePropertyKey: Any]()) { result, pair in
                result[HTTPCookiePropertyKey(pair.key)] = pair.value
            }
            return HTTPCookie(properties: properties)
        }
    }
    
    // 清除 Cookie（登出用）
    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - 同意狀態儲存

struct ConsentStorage {
    static let key = "hasAgreedPrivacyPolicy"

    static var hasAgreed: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

// MARK: - 個資聲明同意畫面

//struct PrivacyConsentView: View {
//    let onAgree: () -> Void
//    let onDisagree: () -> Void
//
//    @State private var hasRead = false
//
//    private let privacyPolicyText = """
//NKUST plus 個人資料保護聲明
//    本 App 為非官方應用程式，與國立高雄科技大學無任何隸屬或合作關係。使用者登入功能將導向國立高雄科技大學學生教務系統（stdsys.nkust.edu.tw）進行驗證，帳號密碼之輸入與驗證均由學校系統處理，本 App 不涉入其過程。
//
//NKUST plus 為保障使用者個人資料，特此說明如下：
//
//一、蒐集目的
//本 App 提供校務系統連結、課表查詢及相關校園資訊服務。
//
//二、蒐集之個人資料類別
//本 App 不會蒐集、儲存或記錄使用者之學校帳號及密碼。
//使用者透過 App 內建 WebView 登入學校系統時，相關驗證資訊係由學校系統處理。本 App 僅透過系統提供之 HTTPCookieStorage 機制，暫時儲存登入狀態（Cookie），以維持使用期間之登入狀態。
//
//三、個人資料利用方式
//Cookie 僅用於：
//　• 維持登入狀態
//　• 提供課表與校務資訊查詢功能
//
//本 App 不會讀取、分析或另行利用帳號相關敏感資訊，亦不會傳送至第三方。
//
//四、資料保存與安全
//Cookie 屬暫時性資料，將依系統機制於期限內自動失效或刪除。使用者亦可透過登出或清除 App 資料方式移除登入狀態。
//
//五、使用者權利
//使用者可隨時停止使用本 App，或清除資料以終止相關處理行為。
//
//六、資料提供
//若使用者不進行登入，將無法使用部分需驗證之功能（如課表查詢）。
//"""
//
//    var body: some View {
//        VStack(spacing: 0) {
//            // 標題列
//            VStack(spacing: 4) {
//                Text("使用前請詳閱")
//                    .font(.title2)
//                    .fontWeight(.bold)
//                Text("個人資料蒐集告知聲明")
//                    .font(.subheadline)
//                    .foregroundStyle(.secondary)
//            }
//            .frame(maxWidth: .infinity)
//            .padding(.vertical, 20)
//            .background(Color(.systemGroupedBackground))
//
//            Divider()
//
//            // 告知聲明內容（可滾動）
//            ScrollView {
//                Text(privacyPolicyText)
//                    .font(.body)
//                    .lineSpacing(4)
//                    .padding(20)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//            }
//            .background(Color(.systemBackground))
//
//            Divider()
//
//            // 已閱讀勾選 + 按鈕區
//            VStack(spacing: 16) {
//                // 已閱讀勾選
//                Button {
//                    hasRead.toggle()
//                } label: {
//                    HStack(spacing: 10) {
//                        Image(systemName: hasRead ? "checkmark.square.fill" : "square")
//                            .font(.title3)
//                            .foregroundStyle(hasRead ? .blue : .secondary)
//                        Text("我已閱讀並了解上述個人資料告知聲明")
//                            .font(.subheadline)
//                            .foregroundStyle(.primary)
//                            .multilineTextAlignment(.leading)
//                        Spacer()
//                    }
//                }
//                .buttonStyle(.plain)
//
//                // 同意 / 不同意 按鈕
//                HStack(spacing: 12) {
//                    Button(role: .destructive) {
//                        onDisagree()
//                    } label: {
//                        Text("不同意")
//                            .fontWeight(.semibold)
//                            .frame(maxWidth: .infinity)
//                            .padding(.vertical, 14)
//                            .background(Color(.systemGray5))
//                            .foregroundStyle(.red)
//                            .clipShape(RoundedRectangle(cornerRadius: 12))
//                    }
//
//                    Button {
//                        onAgree()
//                    } label: {
//                        Text("同意並繼續")
//                            .fontWeight(.semibold)
//                            .frame(maxWidth: .infinity)
//                            .padding(.vertical, 14)
//                            .background(hasRead ? Color.blue : Color(.systemGray4))
//                            .foregroundStyle(.white)
//                            .clipShape(RoundedRectangle(cornerRadius: 12))
//                    }
//                    .disabled(!hasRead)
//                }
//            }
//            .padding(20)
//            .background(Color(.systemGroupedBackground))
//        }
//        .ignoresSafeArea(edges: .bottom)
//    }
//}

// MARK: - 個資聲明同意畫面

struct PrivacyConsentView: View {
    let onAgree: () -> Void
    let onDisagree: () -> Void

    @State private var hasRead = false

    var body: some View {
        VStack(spacing: 0) {
            // 標題列
            VStack(spacing: 4) {
                Text("使用前請詳閱")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("個人資料蒐集告知聲明")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color(.systemGroupedBackground))

            Divider()

            // 告知聲明內容
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // 非官方聲明
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.subheadline)
                            .padding(.top, 1)
                        Text("本 App 為非官方應用程式，與國立高雄科技大學無任何隸屬或合作關係。使用者登入功能將導向國立高雄科技大學學生教務系統（stdsys.nkust.edu.tw）進行驗證，帳號密碼之輸入與真人驗證均由學校系統處理，本 App 不涉入其過程。")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // 各條文
                    PolicySection(number: "一", title: "蒐集目的") {
                        Text("本 App 提供校務系統連結、課表查詢及相關校園資訊服務。")
                    }

                    PolicySection(number: "二", title: "蒐集之個人資料類別") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("本 App 不會蒐集、儲存或記錄使用者之學校帳號及密碼。")
                            Text("使用者透過 App 內建 WebView 登入學校系統時，相關驗證資訊係由學校系統處理。本 App 僅透過系統提供之 HTTPCookieStorage 機制，暫時儲存登入狀態（Cookie），以維持使用期間之登入狀態。")
                        }
                    }

                    PolicySection(number: "三", title: "個人資料利用方式") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Cookie 僅用於：")
                            BulletRow(text: "維持登入狀態")
                            BulletRow(text: "提供課表與校務資訊查詢功能")
                            Text("本 App 不會讀取、分析或另行利用帳號相關敏感資訊，亦不會傳送至第三方。")
                        }
                    }

                    PolicySection(number: "四", title: "資料保存與安全") {
                        Text("登入狀態（Cookie）暫時儲存於裝置本地，不會傳輸至任何伺服器或第三方。Cookie 將依學校系統設定於期限內自動失效，屆時 App 將自動登出，使用者須重新登入。使用者亦可透過登出或清除 App 資料方式主動移除登入狀態。")
                    }

                    PolicySection(number: "五", title: "使用者權利") {
                        Text("使用者可隨時停止使用本 App，或清除資料以終止相關處理行為。")
                    }

                    PolicySection(number: "六", title: "資料提供") {
                        Text("若使用者不進行登入，將無法使用部分需驗證之功能（如課表查詢）。")
                    }
                }
                .padding(20)
            }
            .background(Color(.systemBackground))

            Divider()

            // 已閱讀勾選 + 按鈕區
            VStack(spacing: 16) {
                Button {
                    hasRead.toggle()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: hasRead ? "checkmark.square.fill" : "square")
                            .font(.title3)
                            .foregroundStyle(hasRead ? .blue : .secondary)
                        Text("我已閱讀並了解上述個人資料告知聲明")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)

                HStack(spacing: 12) {
                    Button(role: .destructive) {
                        onDisagree()
                    } label: {
                        Text("不同意")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.systemGray5))
                            .foregroundStyle(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        onAgree()
                    } label: {
                        Text("同意並繼續")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(hasRead ? Color.blue : Color(.systemGray4))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!hasRead)
                }
            }
            .padding(20)
            .background(Color(.systemGroupedBackground))
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - 條文區塊

struct PolicySection<Content: View>: View {
    let number: String
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 條號 + 標題
            HStack(spacing: 6) {
                Text(number)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Color.blue)
                    .clipShape(Circle())
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            // 內文（縮排對齊圓圈寬度）
            content()
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .padding(.leading, 26)
        }
    }
}

// MARK: - Bullet 項目

struct BulletRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 4)
    }
}

// MARK: - 主登入流程

struct LoginView: View {
    @State private var cookies: [HTTPCookie] = []
    @State private var isLoggedIn = false
    @State private var showConsent = false
    
    // 決定顯示上方的"請登入高科學生教務資訊系統"
    @State private var isTransitioning = false

    var body: some View {
        Group {
            if showConsent {
                // 尚未同意過 -> 顯示告知聲明
                PrivacyConsentView {
                    // 同意：記錄並進入登入畫面
                    ConsentStorage.hasAgreed = true
                    showConsent = false
                } onDisagree: {
                    // 不同意：將 App 退至背景（回 iOS 主畫面）
                    UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
                }
            } else if isLoggedIn {
                ContentView(cookies: cookies, isLoggedIn: $isLoggedIn)
            } else {
                ZStack(alignment: .top) {
                    NKUSTWebView(cookies: $cookies, isLoggedIn: $isLoggedIn, isTransitioning: $isTransitioning)
                        .ignoresSafeArea()
                    
                    if !isTransitioning {
                        Text("請登入高科學生教務資訊系統")
                            .padding(8)
                            .frame(maxWidth: .infinity)
                            .background(.thinMaterial)
                    }
                }
            }
        }
        .onAppear {
            if !ConsentStorage.hasAgreed {
                // 從未同意過 -> 先顯示告知聲明
                showConsent = true
                return
            }

            // 已同意過 -> 檢查有沒有儲存的 Cookie
            let saved = CookieStorage.load()
            if !saved.isEmpty {
                cookies = saved
                isLoggedIn = true
            } else {
                CookieStorage.clear()
            }
        }
    }
}

// MARK: - WKWebView 包裝

struct NKUSTWebView: UIViewRepresentable {
    @Binding var cookies: [HTTPCookie]
    @Binding var isLoggedIn: Bool
    @Binding var isTransitioning: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator

        let url = URL(string: "https://stdsys.nkust.edu.tw/student/Account/Login")!
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    // MARK: - Coordinator（偵測登入成功）
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: NKUSTWebView
        
        var overlayView: UIView?

        init(_ parent: NKUSTWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView,
                             decidePolicyFor navigationAction: WKNavigationAction,
                             decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

            if let url = navigationAction.request.url?.absoluteString,
                   url.contains("/student") && !url.contains("Login") {
                    // 立刻蓋上不透明遮罩，使用者完全看不到跳轉
                    DispatchQueue.main.async {
                        self.parent.isTransitioning = true
                        self.showOverlay(on: webView)
                    }
                }
                decisionHandler(.allow)
            }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let urlString = webView.url?.absoluteString else { return }

            print("目前 URL：\(urlString)")

            // 登入成功後 URL 會跳到 /student，不再含 Login
            if urlString.contains("/student") && !urlString.contains("Login") {
                WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                    DispatchQueue.main.async {
                        self.parent.cookies = cookies
                        self.parent.isLoggedIn = true
                        CookieStorage.save(cookies)
                    }
                }
            }
        }
        
        // 螢幕遮罩顏色
        private func showOverlay(on webView: WKWebView) {
            let overlay = UIView(frame: webView.bounds)
            overlay.backgroundColor = UIColor.systemBackground
            overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            
            // App Icon 圖片
            let imageView = UIImageView(image: UIImage(named: "AppIconRemove"))
            
            // 讓圖片完整，怕被拉長
            imageView.contentMode = .scaleAspectFit
            
            // NSLayoutConstraint 置中，不能拿掉
            imageView.translatesAutoresizingMaskIntoConstraints = false
            
            overlay.addSubview(imageView)
            
            // 圖片大小和對齊畫面中央
            NSLayoutConstraint.activate([
                imageView.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
                imageView.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 200),
                imageView.heightAnchor.constraint(equalToConstant: 200)
            ])
            
            webView.addSubview(overlay)
            overlayView = overlay
        }
    }
}

#Preview {
    LoginView()
}
