<p align="center">
  <img src="Doc/NKUST_plus_light.svg" width="140" />
</p>

<h1 align="center">高科 Plus</h1>

<p align="center">
  <a href="https://apps.apple.com/tw/app/%E9%AB%98%E7%A7%91-plus/id6760967835">
    <img src="https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg" height="40" align="middle">
  </a>
  <a href="https://play.google.com/store/apps/details?id=com.wangwesley.nkust_app">
    <img src="https://play.google.com/intl/en_us/badges/static/images/badges/zh-tw_badge_web_generic.png" height="60" align="middle">
  </a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/NKUST-Unofficial%20App-orange" />
  <img src="https://img.shields.io/badge/iOS-17%2B-blue" />
  <img src="https://img.shields.io/badge/SwiftUI-Based-green" />
  <img src="https://img.shields.io/badge/使用者-4.68K%2B-brightgreen" />
  <a href="https://github.com/wangwesley1125/NKUST_plus_Android">
    <img src="https://img.shields.io/badge/Android%20版-NKUST__plus__Android-3DDC84" />
  </a>
</p>

一款以 **SwiftUI** 打造的 iOS App，專為高科大學生設計，整合校務系統與校園資訊，提供更直覺、快速且安全的使用體驗，並在使用前以清楚的隱私告知與同意流程保障使用者權益。

> Android 版請見 [NKUST_plus_Android](https://github.com/wangwesley1125/NKUST_plus_Android)

## 核心特色

- **隱私優先設計**
  - 首次使用提供完整隱私告知與使用者同意流程
  - 登入狀態僅保存必要的 Cookie，所有資料都只存在使用者自己的裝置

- **自動登入體驗**
  - 使用 `WKWebView` 串接校務系統
  - 自動偵測登入狀態並持久化 Cookie
  - App 重開後維持登入狀態
  - 可選擇開啟 AutoFill，帳號密碼以加密方式儲存於裝置 **Keychain**

- **原生 SwiftUI 介面**
  - 採用 `.material` 視覺效果
  - 簡潔、流暢、現代化 UI

## 功能總覽

### 1. 首頁（Dashboard）
- 畢業學分進度與未通過項目
- 正在進行的課程顯示
- 即將開始的課程顯示

---

### 2. 個人課表
- 清楚顯示每日課程，可自行選擇顯示空堂
- 支援列表與週課表（格狀）兩種顯示方式
- 快速掌握上課時間與教室

---

### 3. 成績
- 期中成績、當學期成績
- 歷年成績

---

### 4. 個人資料
- 學生資訊、學分明細與修課規劃
- 圖書館借書證
- 在學證明
- 行事曆

---

### 5. 校園地圖
- 整合高科各校區資訊
- 提供快速查找與定位

---

### 6. 桌面小工具
- 不用打開 App 就能看今日課表

---

### 7. 關於
- 關於開發者
- 版本資訊
- 學生專區
- 常用的外部連結
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
  - `CredentialStorage`：使用者選擇開啟 AutoFill 時，將帳密加密儲存於 Keychain

## 隱私與資料處理
- 登入流程在 App 內建 `WKWebView` 中完成，驗證由學校系統處理
- 僅將登入狀態所需的 Cookie 儲存在本機（`UserDefaults`）以維持登入
- 帳號密碼**只有在使用者開啟 AutoFill 時**才會保存，並以加密方式儲存於裝置 Keychain，不會傳輸至任何伺服器或第三方；可隨時在 App 內刪除
- 使用者可透過登出或移除 App 資料來清除 Cookie 與狀態

## 系統需求
- iOS 17 以上
- iPhone, iPad 裝置

## 版本紀錄

請參閱 [Releases](https://github.com/wangwesley1125/NKUST_plus/releases) 頁面

## 相關專案
- Android 版：[wangwesley1125/NKUST_plus_Android](https://github.com/wangwesley1125/NKUST_plus_Android)

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
