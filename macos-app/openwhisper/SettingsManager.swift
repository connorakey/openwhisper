//
//  SettingsManager.swift
//  openwhisper
//
//  Created by Connor on 13/1/2026.
//

import Foundation
import SwiftUI
import Combine

enum ThemeOption: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
}

enum ModifierKey: String, CaseIterable {
    case function = "Fn"
    case control = "Control"
    case option = "Option"
    case command = "Command"
    
    var carbonFlags: Int {
        switch self {
        case .function: return 0x800000 // fnKey
        case .control: return 0x1000 // controlKey
        case .option: return 0x800 // optionKey
        case .command: return 0x100 // cmdKey
        }
    }
}

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var apiUrl: String {
        didSet {
            UserDefaults.standard.set(apiUrl, forKey: "apiUrl")
        }
    }
    
    @Published var theme: ThemeOption {
        didSet {
            UserDefaults.standard.set(theme.rawValue, forKey: "theme")
            applyTheme()
        }
    }
    
    @Published var modifierKey: ModifierKey {
        didSet {
            UserDefaults.standard.set(modifierKey.rawValue, forKey: "modifierKey")
        }
    }
    
    @Published var secondKey: String {
        didSet {
            UserDefaults.standard.set(secondKey, forKey: "secondKey")
        }
    }
    
    @Published var authorizationKey: String {
        didSet {
            saveAuthorizationKey(authorizationKey)
        }
    }
    
    private init() {
        self.apiUrl = UserDefaults.standard.string(forKey: "apiUrl") ?? "http://127.0.0.1:8000/transcribe"
        
        let themeString = UserDefaults.standard.string(forKey: "theme") ?? ThemeOption.system.rawValue
        self.theme = ThemeOption(rawValue: themeString) ?? .system
        
        let modifierString = UserDefaults.standard.string(forKey: "modifierKey") ?? ModifierKey.option.rawValue
        self.modifierKey = ModifierKey(rawValue: modifierString) ?? .option
        
        self.secondKey = UserDefaults.standard.string(forKey: "secondKey") ?? "Space"
        self.authorizationKey = "" // Initialize with empty string first
        
        // Now load the actual authorization key
        self.authorizationKey = loadAuthorizationKey()
        
        applyTheme()
    }
    
    private func applyTheme() {
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                switch self.theme {
                case .light:
                    window.appearance = NSAppearance(named: .aqua)
                case .dark:
                    window.appearance = NSAppearance(named: .darkAqua)
                case .system:
                    window.appearance = nil
                }
            }
        }
    }
    
    private func saveAuthorizationKey(_ key: String) {
        let data = Data(key.utf8)
        let status = SecItemAdd([
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: "openwhisper.authKey",
            kSecValueData: data
        ] as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            SecItemUpdate([
                kSecClass: kSecClassGenericPassword,
                kSecAttrAccount: "openwhisper.authKey"
            ] as CFDictionary, [
                kSecValueData: data
            ] as CFDictionary)
        }
    }
    
    private func loadAuthorizationKey() -> String {
        var result: AnyObject?
        let status = SecItemCopyMatching([
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: "openwhisper.authKey",
            kSecReturnData: true
        ] as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8) ?? ""
        }
        return ""
    }
}
