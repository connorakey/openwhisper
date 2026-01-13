//
//  HotkeyManager.swift
//  openwhisper
//
//  Created by Connor on 13/1/2026.
//

import Foundation
import Carbon
import AppKit

class HotkeyManager {
    static let shared = HotkeyManager()
    
    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    var onHotKeyPressed: (() -> Void)?
    var onHotKeyReleased: (() -> Void)?
    
    private init() {}
    
    func registerHotKey(modifierKey: ModifierKey, secondKey: String) {
        unregisterHotKey()
        
        guard let keyCode = getKeyCode(for: secondKey) else {
            NSLog("❌ Invalid key: \(secondKey)")
            return
        }
        
        NSLog("🔧 Registering hotkey: \(modifierKey.rawValue) + \(secondKey) (code: \(keyCode))")
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        var eventType2 = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        
        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, event, userData) -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            
            var eventKind = GetEventKind(event)
            
            if eventKind == UInt32(kEventHotKeyPressed) {
                NSLog("⬇️ HOTKEY PRESSED")
                manager.onHotKeyPressed?()
            } else if eventKind == UInt32(kEventHotKeyReleased) {
                NSLog("⬆️ HOTKEY RELEASED")
                manager.onHotKeyReleased?()
            }
            
            return noErr
        }, 2, [eventType, eventType2], Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
        
        var hotKeyID = EventHotKeyID(signature: OSType(0x4F575350), id: 1)
        let modifiers = UInt32(modifierKey.carbonFlags)
        
        let status = RegisterEventHotKey(UInt32(keyCode), modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        NSLog("✅ Hotkey registration status: \(status)")
    }
    
    func unregisterHotKey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
    
    private func getKeyCode(for key: String) -> Int? {
        let keyMap: [String: Int] = [
            "A": 0, "S": 1, "D": 2, "F": 3, "H": 4, "G": 5, "Z": 6, "X": 7, "C": 8, "V": 9,
            "B": 11, "Q": 12, "W": 13, "E": 14, "R": 15, "Y": 16, "T": 17, "1": 18, "2": 19,
            "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26, "8": 28, "0": 29,
            "]": 30, "O": 31, "U": 32, "I": 34, "P": 35, "L": 37, "J": 38, "K": 40, ";": 41,
            "[": 33, ",": 43, "/": 44, "N": 45, "M": 46, ".": 47, "`": 50, "-": 27,
            "Space": 49, "Return": 36, "Tab": 48, "Delete": 51, "Escape": 53,
            "Left": 123, "Right": 124, "Down": 125, "Up": 126
        ]
        
        return keyMap[key.uppercased()] ?? keyMap[key]
    }
}
