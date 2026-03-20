# NKUST plus

一個以 SwiftUI 開發的 iOS App，提供高科大學生透過 App 便捷存取校務系統、維持登入狀態，並在使用前以清楚的隱私告知與同意流程保障使用者權益。

## 特色與功能
- 隱私告知與同意流程（首次使用會顯示）
- 內建 WebView（WKWebView）導向高科大學生系統登入頁
- 自動偵測登入成功（依網址路徑變化判斷）
- 擷取並持久化 Cookie 以維持登入狀態（跨啟動）
- 登出與清除 Cookie（可回到未登入狀態）
- 以 SwiftUI 建構的簡潔介面與 .material 視覺效果

## 截圖
- 登入前的隱私告知畫面
- 登入中的 WebView 介面
- 登入後主畫面 / 功能頁

## 架構總覽
- Login Flow
  - `LoginView`：進入點，決定顯示隱私告知、登入頁或主內容
  - `PrivacyConsentView`：顯示隱私聲明，使用者需勾選已閱讀並同意
  - `NKUSTWebView`：以 `WKWebView` 載入校務系統並監聽導覽事件
- Storage
  - `CookieStorage`：將登入後取得的 Cookie 序列化並儲存至 `UserDefaults`，供下次啟動使用
  - `ConsentStorage`：記錄是否已同意隱私聲明（`UserDefaults`）

## 隱私與資料處理
- App 不會蒐集或儲存學校帳號、密碼
- 登入流程在 App 內建 `WKWebView` 中完成，驗證由學校系統處理
- 僅將登入狀態所需的 Cookie 儲存在本機（`UserDefaults`）以維持登入
- 使用者可透過登出或移除 App 資料來清除 Cookie 與狀態

## 系統需求
- iOS 26 以上

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
