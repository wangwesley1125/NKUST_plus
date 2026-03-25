<p align="center">
  <img src="Doc/NKUST_plus_light.svg" width="140" />
</p>

<h1 align="center">高科 Plus</h1>

<p align="center">
  <a href="https://apps.apple.com/tw/app/%E9%AB%98%E7%A7%91-plus/id6760967835">
    <img src="https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg" width="160">
  </a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/NKUST-Unofficial%20App-orange" />
  <img src="https://img.shields.io/badge/iOS-26%2B-blue" />
  <img src="https://img.shields.io/badge/SwiftUI-Based-green" />
</p>

一款以 **SwiftUI** 打造的 iOS App，專為高科大學生設計，整合校務系統與校園資訊，提供更直覺、快速且安全的使用體驗，並在使用前以清楚的隱私告知與同意流程保障使用者權益。

## 核心特色

- **隱私優先設計**
  - 首次使用提供完整隱私告知與使用者同意流程
  - 不儲存帳號與密碼，僅保存必要 Cookie

- **自動登入體驗**
  - 使用 `WKWebView` 串接校務系統
  - 自動偵測登入狀態並持久化 Cookie
  - App 重開後維持登入狀態

- **原生 SwiftUI 介面**
  - 採用 `.material` 視覺效果
  - 簡潔、流暢、現代化 UI

##  功能總覽

### 1. 首頁（Dashboard）
-  高雄即時天氣與溫度
-  正在進行的課程顯示
-  即將開始的課程顯示

---

### 2. 個人課表
- 清楚顯示每日課程，可自行選擇顯示空堂
- 快速掌握上課時間與教室

---

### 3. 歷年成績
- 直接透過 App 直接看成績

---

### 4. 校園地圖
- 整合高科各校區資訊
- 提供快速查找與定位

---

### 5. 關於
- 關於開發者
- 版本資訊
- 開源專案
- 隱私政策與版權聲明
- 問題回報

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
- iPhone 裝置

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
