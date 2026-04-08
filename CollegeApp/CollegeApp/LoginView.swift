import SwiftUI
import WidgetKit
import WebKit
import Security

// MARK: - Cookie 持久化工具

struct CookieStorage {
    static let key = "savedCookies"
    
    static func save(_ cookies: [HTTPCookie]) {
        let data = cookies.compactMap { cookie -> [String: Any]? in
            return HTTPCookie.requestHeaderFields(with: [cookie]).isEmpty ? nil : cookie.properties?.reduce(into: [String: Any]()) { result, pair in
                result[pair.key.rawValue] = pair.value
            }
        }
        UserDefaults.standard.set(data, forKey: key)
    }
    
    static func load() -> [HTTPCookie] {
        guard let data = UserDefaults.standard.array(forKey: key) as? [[String: Any]] else { return [] }
        return data.compactMap { dict in
            let properties = dict.reduce(into: [HTTPCookiePropertyKey: Any]()) { result, pair in
                result[HTTPCookiePropertyKey(pair.key)] = pair.value
            }
            return HTTPCookie(properties: properties)
        }
    }
    
    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - Credential Storage（Keychain）
// 注意：啟用此功能後，隱私政策條文二需同步更新，
// 說明「使用者可選擇性地將帳密儲存於裝置 Keychain 以供 AutoFill 使用」。

struct CredentialStorage {
    private static let service = "tw.edu.nkust.stdsys.autofill"

    static func save(username: String, password: String) {
        write(value: username, account: "username")
        write(value: password, account: "password")
    }

    static func load() -> (username: String, password: String)? {
        guard let u = read(account: "username"),
              let p = read(account: "password"),
              !u.isEmpty else { return nil }
        return (u, p)
    }

    static func clear() {
        delete(account: "username")
        delete(account: "password")
    }

    // MARK: Private Keychain helpers

    private static func write(value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let attributes: [CFString: Any] = [kSecValueData: data]
        if SecItemUpdate(query as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    private static func read(account: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:        kSecClassGenericPassword,
            kSecAttrService:  service,
            kSecAttrAccount:  account,
            kSecReturnData:   true,
            kSecMatchLimit:   kSecMatchLimitOne
        ]
        var item: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func delete(account: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
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

struct PrivacyConsentView: View {
    let onAgree: () -> Void
    let onDisagree: () -> Void

    @State private var hasRead = false

    var body: some View {
        VStack(spacing: 0) {
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

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

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

                    PolicySection(number: "一", title: "蒐集目的") {
                        Text("本 App 提供校務系統連結、課表查詢及相關校園資訊服務。")
                    }

                    PolicySection(number: "二", title: "蒐集之個人資料類別") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("使用者透過 App 內建 WebView 登入學校系統時，相關驗證資訊係由學校系統處理。本 App 僅透過系統提供之 HTTPCookieStorage 機制，暫時儲存登入狀態（Cookie），以維持使用期間之登入狀態。")
                            Text("若使用者選擇開啟「AutoFill 自動填入」功能，帳號密碼將以加密方式儲存於裝置本地 Keychain，不會傳輸至任何伺服器或第三方。")
                        }
                    }

                    PolicySection(number: "三", title: "個人資料利用方式") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Cookie 及帳密（如啟用 AutoFill）僅用於：")
                            BulletRow(text: "維持登入狀態")
                            BulletRow(text: "提供課表與校務資訊查詢功能")
                            BulletRow(text: "AutoFill 自動填入登入表單（需使用者明確同意）")
                            Text("本 App 不會讀取、分析或另行利用帳號相關敏感資訊，亦不會傳送至第三方。")
                        }
                    }

                    PolicySection(number: "四", title: "資料保存與安全") {
                        Text("登入狀態（Cookie）暫時儲存於裝置本地，不會傳輸至任何伺服器或第三方。Cookie 將依學校系統設定於期限內自動失效，屆時 App 將自動登出，使用者須重新登入。使用者亦可透過登出或清除 App 資料方式主動移除登入狀態。AutoFill 帳密儲存於裝置 Keychain，使用者可隨時在 App 內刪除。")
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
            HStack(spacing: 6) {
                Text(number)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
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
            Text("•").font(.footnote).foregroundStyle(.secondary)
            Text(text).font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.leading, 4)
    }
}

// MARK: - AutoFill Banner
// 當使用者進入登入頁且 Keychain 有儲存帳密時，從底部滑出此提示列。

struct AutoFillBanner: View {
    let username: String
    let onFill: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // 圖示
            Image(systemName: "key.horizontal.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 9))

            // 文字
            VStack(alignment: .leading, spacing: 2) {
                Text("自動填入帳號密碼")
                    .font(.subheadline.weight(.semibold))
                Text(username)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // 填入按鈕
            Button {
                onFill()
            } label: {
                Text("填入")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }

            // 關閉按鈕
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .padding(.horizontal, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - 儲存密碼 Sheet
// 登入成功後詢問是否將帳密存入 Keychain。
// isUpdate = true 時表示 Keychain 已有舊帳密，改為更新提示。

struct SavePasswordSheet: View {
    let username: String
    let isUpdate: Bool
    let onSave: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // 圖示 + 標題
            VStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.blue)
                    .padding(.top, 8)

                Text(isUpdate ? "更新已儲存的密碼？" : "儲存帳號密碼？")
                    .font(.title3.weight(.bold))

                Text("帳密將以加密方式儲存於裝置\nKeychain，下次登入時可快速自動填入")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // 帳號預覽列
            HStack(spacing: 10) {
                Image(systemName: "person.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.title3)
                Text(username)
                    .font(.callout)
                Spacer()
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.green)
                    .font(.callout)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // 按鈕
            VStack(spacing: 10) {
                Button {
                    onSave()
                } label: {
                    Text(isUpdate ? "更新密碼" : "儲存密碼")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button(role: .cancel) {
                    onSkip()
                } label: {
                    Text("不要儲存")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }
}

// MARK: - 主登入流程

struct LoginView: View {
    @State private var cookies: [HTTPCookie] = []
    @State private var isLoggedIn = false
    @State private var showConsent = false
    @State private var isTransitioning = false

    // AutoFill 相關狀態
    // Keychain 讀出的帳密，傳給 WebView 用於注入
    @State private var savedCredentials: (username: String, password: String)? = nil
    // 登入頁載入完成後，WebView 設為 true → 顯示 Banner
    @State private var showAutoFillBanner = false
    // 使用者點「填入」後設為 true → WebView 執行 JS 注入
    @State private var shouldAutoFill = false
    // 登入成功後偵測到的帳密，用於詢問是否儲存
    @State private var pendingCredentials: (username: String, password: String)? = nil
    @State private var showSavePasswordSheet = false
    
    // 訪客登入
    @State private var isGuest = false
    
    // 刷新頁面
    @State private var shouldReload = false
    
    // 版本更新通知
    @State private var newAppVersion: String? = nil

    var body: some View {
        
        Group {
            if showConsent {
                PrivacyConsentView {
                    ConsentStorage.hasAgreed = true
                    showConsent = false
                    savedCredentials = CredentialStorage.load()
                } onDisagree: {
                    UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
                }

            } else if isLoggedIn {
                
                ContentView(cookies: cookies, isLoggedIn: $isLoggedIn)
                
            } else if isGuest {
                
                GuestContentView(isGuest: $isGuest)
                
            } else {
                ZStack(alignment: .top) {
                    NKUSTWebView(
                        cookies: $cookies,
                        isLoggedIn: $isLoggedIn,
                        isTransitioning: $isTransitioning,
                        showAutoFillBanner: $showAutoFillBanner,
                        shouldAutoFill: $shouldAutoFill,
                        shouldReload: $shouldReload,
                        savedCredentials: savedCredentials,
                        onDetectedCredentials: { username, password in
                            // 登入成功後，判斷是否需要新增或更新儲存的帳密
                            let existing = CredentialStorage.load()
                            let isNew      = existing == nil
                            let isChanged  = existing?.username != username || existing?.password != password
                            if isNew || isChanged {
                                pendingCredentials = (username, password)
                                //showSavePasswordSheet = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                    showSavePasswordSheet = true
                                }
                            }
                        }
                    )
                    .ignoresSafeArea()

                    if !isTransitioning {
                        ZStack {
                            Text("歡迎使用高科 Plus")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                            
                            HStack {
                                // 刷新頁面按鈕
                                Button {
                                    shouldReload = true
                                } label: {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                }
                                
                                Spacer()
                                
                                // 訪客登入按鈕
                                Button {
                                    UserDefaults.standard.set(true, forKey: "isGuest")
                                    isGuest = true
                                } label: {
                                    Text("\(Image(systemName: "person.fill"))訪客")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(Color.blue)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(.thinMaterial)
                    }
                }
                // AutoFill Banner（底部）
                .overlay(alignment: .bottom) {
                    if showAutoFillBanner, let cred = savedCredentials {
                        AutoFillBanner(
                            username: cred.username,
                            onFill: {
                                withAnimation(.spring(response: 0.3)) {
                                    showAutoFillBanner = false
                                }
                                shouldAutoFill = true
                            },
                            onDismiss: {
                                withAnimation(.spring(response: 0.3)) {
                                    showAutoFillBanner = false
                                }
                            }
                        )
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        // Sheet 掛在 Group 外：isLoggedIn 翻轉後 Sheet 仍可持續顯示
        .sheet(isPresented: $showSavePasswordSheet) {
            if let pending = pendingCredentials {
                SavePasswordSheet(
                    username: pending.username,
                    isUpdate: CredentialStorage.load() != nil,
                    onSave: {
                        CredentialStorage.save(username: pending.username, password: pending.password)
                        savedCredentials = (pending.username, pending.password)
                        showSavePasswordSheet = false
                    },
                    onSkip: {
                        showSavePasswordSheet = false
                    }
                )
            }
        }
        .onAppear {
            if !ConsentStorage.hasAgreed {
                showConsent = true
                return
            }

            // 從 Keychain 載入帳密（供 AutoFill 用）
            savedCredentials = CredentialStorage.load()

            // 從 UserDefaults 載入 Cookie（維持登入狀態）
            let saved = CookieStorage.load()
            if !saved.isEmpty {
                cookies = saved
                isLoggedIn = true
            } else {
                CookieStorage.clear()
            }
            
            if UserDefaults.standard.bool(forKey: "isGuest") {
                isGuest = true
                return
            }
        }
        .onChange(of: isLoggedIn) { _, newValue in
            if !newValue {
                isTransitioning = false
            }
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
        .task {
            // 模擬有新版本
            // newAppVersion = "1.3.4"
            newAppVersion = await AppUpdateChecker.check()
        }
    }
}

// MARK: - WKWebView 包裝

struct NKUSTWebView: UIViewRepresentable {
    @Binding var cookies: [HTTPCookie]
    @Binding var isLoggedIn: Bool
    @Binding var isTransitioning: Bool
    /// WebView 偵測到登入頁 + 有儲存帳密時，設為 true 讓 LoginView 顯示 Banner
    @Binding var showAutoFillBanner: Bool
    /// LoginView 設為 true 後，WebView 執行 JS 注入帳密
    @Binding var shouldAutoFill: Bool
    /// 刷新頁面
    @Binding var shouldReload: Bool

    var savedCredentials: (username: String, password: String)?
    /// 登入成功前從表單擷取的帳密，回傳給 LoginView 決定是否儲存
    var onDetectedCredentials: ((String, String) -> Void)?

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

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Coordinator 持有的 parent 是 struct（值型別），每次 SwiftUI 重繪都要手動同步，
        // 否則 didFinish 裡讀到的 savedCredentials 會是舊的（nil）。
        context.coordinator.parent = self

        // 接收到填入指令 -> 執行 JS 注入，並立即重設旗標避免重複觸發
        if shouldAutoFill {
            context.coordinator.injectCredentials(into: webView)
            DispatchQueue.main.async {
                self.shouldAutoFill = false
            }
        }
        
        // 刷新頁面
        if shouldReload {
            webView.reload()
            DispatchQueue.main.async {
                self.shouldReload = false
            }
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: NKUSTWebView
        var overlayView: UIView?

        init(_ parent: NKUSTWebView) {
            self.parent = parent
        }

        // MARK: JS 注入帳密
        func injectCredentials(into webView: WKWebView) {
            guard let cred = parent.savedCredentials else { return }

            // 跳脫單引號，防止 JS 注入問題
            let u = cred.username
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
            let p = cred.password
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")

            // 依序嘗試 id、name 屬性、再 fallback 到 type
            let js = """
            (function() {
                var uField = document.querySelector('#UserName')
                    || document.querySelector('input[name="UserName"]')
                    || document.querySelector('input[type="text"]');
                var pField = document.querySelector('#Password')
                    || document.querySelector('input[name="Password"]')
                    || document.querySelector('input[type="password"]');
                if (uField) {
                    uField.value = '\(u)';
                    uField.dispatchEvent(new Event('input',  { bubbles: true }));
                    uField.dispatchEvent(new Event('change', { bubbles: true }));
                }
                if (pField) {
                    pField.value = '\(p)';
                    pField.dispatchEvent(new Event('input',  { bubbles: true }));
                    pField.dispatchEvent(new Event('change', { bubbles: true }));
                }
            })();
            """
            webView.evaluateJavaScript(js)
        }

        // MARK: 即將導航：在表單還在 DOM 時擷取帳密
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

            let destURL = navigationAction.request.url?.absoluteString ?? ""

            // 從登入頁跳轉到 /student（登入成功的瞬間）
            if let currentURL = webView.url?.absoluteString,
               currentURL.contains("Login"),
               destURL.contains("/student") && !destURL.contains("Login") {

                // 立刻蓋上遮罩
                DispatchQueue.main.async {
                    self.parent.isTransitioning = true
                    self.showOverlay(on: webView)
                }

                // 先擷取帳密，再放行導航
                let extractJS = """
                (function() {
                    var u = document.querySelector('#UserName')
                        || document.querySelector('input[name="UserName"]')
                        || document.querySelector('input[type="text"]');
                    var p = document.querySelector('#Password')
                        || document.querySelector('input[name="Password"]')
                        || document.querySelector('input[type="password"]');
                    return JSON.stringify({
                        u: u ? u.value : '',
                        p: p ? p.value : ''
                    });
                })();
                """
                webView.evaluateJavaScript(extractJS) { [weak self] result, _ in
                    defer { decisionHandler(.allow) }   // 無論如何放行
                    guard
                        let jsonStr = result as? String,
                        let data    = jsonStr.data(using: .utf8),
                        let json    = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                        let u = json["u"], let p = json["p"],
                        !u.isEmpty, !p.isEmpty
                    else { return }

                    DispatchQueue.main.async {
                        self?.parent.onDetectedCredentials?(u, p)
                    }
                }
                return  // decisionHandler 已在 evaluateJavaScript 回呼中呼叫
            }

            decisionHandler(.allow)
        }

        // MARK: 頁面載入完成
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let urlString = webView.url?.absoluteString else { return }
            print("目前 URL：\(urlString)")

            // 登入頁載入完成：若有儲存帳密，顯示 AutoFill Banner
            if urlString.contains("Login") {
                if parent.savedCredentials != nil {
                    DispatchQueue.main.async {
                        withAnimation(.spring(response: 0.4)) {
                            self.parent.showAutoFillBanner = true
                        }
                    }
                }
                return
            }

            // 登入成功後頁面：儲存 Cookie 並切換到主畫面
            if urlString.contains("/student") && !urlString.contains("Login") {
                WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                    DispatchQueue.main.async {
                        self.parent.cookies = cookies
                        self.parent.isLoggedIn = true
                        CookieStorage.save(cookies)
                    }
                    
                    // 登入成功後背景更新課表 Widget
                    Task {
                        do {
                            let html = try await CourseService.shared.fetchCourses(cookies: cookies)
                            let parsed = try CourseParser.parse(html: html)
                            let codable = parsed.map {
                                CourseCodable(name: $0.name, teacher: $0.teacher,
                                              room: $0.room, period: $0.period, weekday: $0.weekday)
                            }
                            CourseStorage.shared.save(courses: codable)
                            WidgetCenter.shared.reloadAllTimelines()
                            print("✅ 登入後已更新 Widget，共 \(codable.count) 堂課")
                        } catch {
                            print("❌ 登入後更新課表失敗：\(error)")
                        }
                    }
                }
            }
        }

        // MARK: 螢幕遮罩（登入過渡動畫）
        private func showOverlay(on webView: WKWebView) {
            let overlay = UIView(frame: webView.bounds)
            overlay.backgroundColor = UIColor.systemBackground
            overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]

            let imageView = UIImageView(image: UIImage(named: "AppIconRemove"))
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false

            overlay.addSubview(imageView)
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

// 版本更新
struct AppUpdateChecker {
    static func check() async -> String? {
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        let urlString = "https://itunes.apple.com/tw/lookup?bundleId=\(bundleID)"
        guard let url = URL(string: urlString),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let appStoreVersion = results.first?["version"] as? String
        else { return nil }

        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        return currentVersion.compare(appStoreVersion, options: .numeric) == .orderedAscending ? appStoreVersion : nil
    }
}

#Preview {
    LoginView()
}
