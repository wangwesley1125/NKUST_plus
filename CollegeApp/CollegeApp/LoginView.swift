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


struct LoginView: View {
    @State private var cookies: [HTTPCookie] = []
    @State private var isLoggedIn = false
    
    var body: some View {
        if isLoggedIn {
            ContentView(cookies: cookies, isLoggedIn: $isLoggedIn)
        } else {
            ZStack(alignment: .top) {
                NKUSTWebView(cookies: $cookies, isLoggedIn: $isLoggedIn)
                    .ignoresSafeArea()
                
                Text("請登入高科學生系統")
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(.thinMaterial)
            }
            .onAppear {
                // App 啟動時檢查有沒有存過的 Cookie
                let saved = CookieStorage.load()
                if !saved.isEmpty {
                    cookies = saved
                    isLoggedIn = true
                } else {
                    CookieStorage.clear() // 過期就清掉，讓使用者重登
                }
            }
        }
    }
}

// MARK: - WKWebView 包裝
struct NKUSTWebView: UIViewRepresentable {
    @Binding var cookies: [HTTPCookie]
    @Binding var isLoggedIn: Bool
    
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
        
        init(_ parent: NKUSTWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let urlString = webView.url?.absoluteString else { return }
            
            print("目前 URL：\(urlString)") // 方便 debug
            
            // 登入成功後 URL 會跳到 /student，不再含 Login
            if urlString.contains("/student") && !urlString.contains("Login") {
                WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                    DispatchQueue.main.async {
                        self.parent.cookies = cookies
                        self.parent.isLoggedIn = true
                        
                        // Debug：印出所有 Cookie 名稱
                        print("=== 取得 Cookie ===")
                        cookies.forEach { print("\($0.name) = \($0.value.prefix(20))...") }
                        
                        // 登入成功後儲存 Cookie
                        CookieStorage.save(cookies)
                    }
                }
            }
        }
    }
}

#Preview {
    LoginView()
}
