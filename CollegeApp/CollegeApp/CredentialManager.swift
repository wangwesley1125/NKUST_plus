//
//  CredentialManager.swift
//  CollegeApp
//
//  Created by Wesley Wang on 2026/3/20.
//

import Security
import LocalAuthentication

struct CredentialManager {
    
    private static let account = "nkust_login"
    private static let service = Bundle.main.bundleIdentifier ?? "com.nkustplus"
    
    // 儲存帳密（會觸發 Face ID）
    static func save(username: String, password: String) throws {
        let credentials = "\(username):\(password)".data(using: .utf8)!
        
        // 建立生物辨識存取控制
        let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            .biometryAny,  // Face ID 或 Touch ID
            nil
        )!
        
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      service,
            kSecAttrAccount as String:      account,
            kSecValueData as String:        credentials,
            kSecAttrAccessControl as String: access
        ]
        
        // 先刪除舊的再存新的
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    // 讀取帳密（會觸發 Face ID）
    static func load() throws -> (username: String, password: String) {
        let context = LAContext()
        context.localizedReason = "驗證身份以自動填入帳號密碼"
        
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      service,
            kSecAttrAccount as String:      account,
            kSecReturnData as String:       true,
            kSecUseAuthenticationContext as String: context
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let str  = String(data: data, encoding: .utf8) else {
            throw KeychainError.loadFailed(status)
        }
        
        let parts = str.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { throw KeychainError.invalidFormat }
        
        return (username: parts[0], password: parts[1])
    }
    
    // 刪除帳密（登出時呼叫）
    static func delete() {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    // 是否已儲存帳密
    static var hasSaved: Bool {
        let context = LAContext()
        context.interactionNotAllowed = true
        
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      service,
            kSecAttrAccount as String:      account,
            kSecUseAuthenticationContext as String: context
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }
    
    enum KeychainError: LocalizedError {
        case saveFailed(OSStatus)
        case loadFailed(OSStatus)
        case invalidFormat
        
        var errorDescription: String? {
            switch self {
            case .saveFailed:    return "帳密儲存失敗"
            case .loadFailed:    return "無法讀取帳密，請重新登入"
            case .invalidFormat: return "資料格式錯誤"
            }
        }
    }
}

