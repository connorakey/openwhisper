//
//  TextTyper.swift
//  openwhisper
//
//  Created by Connor on 13/1/2026.
//

import Foundation
import AppKit
import CoreGraphics

class TextTyper {
    static let shared = TextTyper()
    
    private init() {}
    
    func typeText(_ text: String) {
        // First, check if we have accessibility permission
        if !AXIsProcessTrusted() {
            print("⚠️ Accessibility not trusted, attempting fallback via pasteboard")
            typeUsingPasteboard(text)
            return
        }

        // Use normal method if accessibility is available
        typeViaAccessibility(text)
    }

    private func typeViaAccessibility(_ text: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Ensure we're not the active app before typing
            // This allows the text to be typed into the previously focused window
            DispatchQueue.main.async {
                NSApp.hide(nil)
            }
            
            // Give time for the previous app to become active
            Thread.sleep(forTimeInterval: 0.3)
            
            let source = CGEventSource(stateID: .hidSystemState)
            
            for char in text {
                self.typeCharacter(char, source: source)
                Thread.sleep(forTimeInterval: 0.015)
            }
        }
    }
    
    private func typeUsingPasteboard(_ text: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Copy text to pasteboard
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)

            // Hide our app
            DispatchQueue.main.async {
                NSApp.hide(nil)
            }

            // Wait for focus to change
            Thread.sleep(forTimeInterval: 0.5)

            // Try using AppleScript to paste
            let script = "tell application \"System Events\" to keystroke \"v\" using command down"
            var error: NSDictionary?

            if let scriptObject = NSAppleScript(source: script) {
                scriptObject.executeAndReturnError(&error)
                if error == nil {
                    print("📋 Text pasted via AppleScript")
                    return
                }
            }

            // If AppleScript fails, try with a small delay and try again
            Thread.sleep(forTimeInterval: 0.3)

            // Try with IO Kit method as last resort
            let source = CGEventSource(stateID: .hidSystemState)
            let vKeyCode: CGKeyCode = 9 // V key

            // Press and release Cmd+V without needing accessibility
            if let event = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true) {
                event.flags = [.maskCommand]
                event.post(tap: .cghidEventTap)
                Thread.sleep(forTimeInterval: 0.1)
            }

            if let event = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) {
                event.post(tap: .cghidEventTap)
            }

            print("📋 Text pasted via clipboard (IO method)")
        }
    }

    private func typeCharacter(_ char: Character, source: CGEventSource?) {
        if let keyInfo = getKeyCode(for: char) {
            let keyCode = keyInfo.0
            let needsShift = keyInfo.1
            
            // Press shift if needed
            if needsShift {
                let shiftDown = CGEvent(keyboardEventSource: source, virtualKey: 56, keyDown: true)
                shiftDown?.flags = .maskShift
                shiftDown?.post(tap: .cghidEventTap)
                Thread.sleep(forTimeInterval: 0.005)
            }
            
            // Key down
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
            if needsShift {
                keyDown?.flags = .maskShift
            }
            keyDown?.post(tap: .cghidEventTap)
            
            Thread.sleep(forTimeInterval: 0.005)
            
            // Key up
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
            keyUp?.post(tap: .cghidEventTap)
            
            // Release shift if needed
            if needsShift {
                Thread.sleep(forTimeInterval: 0.005)
                let shiftUp = CGEvent(keyboardEventSource: source, virtualKey: 56, keyDown: false)
                shiftUp?.post(tap: .cghidEventTap)
            }
        }
    }
    
    private func getKeyCode(for char: Character) -> (CGKeyCode, Bool)? {
        let keyMap: [Character: (CGKeyCode, Bool)] = [
            // Lowercase letters (no shift)
            "a": (0, false), "b": (11, false), "c": (8, false), "d": (2, false),
            "e": (14, false), "f": (3, false), "g": (5, false), "h": (4, false),
            "i": (34, false), "j": (38, false), "k": (40, false), "l": (37, false),
            "m": (46, false), "n": (45, false), "o": (31, false), "p": (35, false),
            "q": (12, false), "r": (15, false), "s": (1, false), "t": (17, false),
            "u": (32, false), "v": (9, false), "w": (13, false), "x": (7, false),
            "y": (16, false), "z": (6, false),
            
            // Uppercase letters (with shift)
            "A": (0, true), "B": (11, true), "C": (8, true), "D": (2, true),
            "E": (14, true), "F": (3, true), "G": (5, true), "H": (4, true),
            "I": (34, true), "J": (38, true), "K": (40, true), "L": (37, true),
            "M": (46, true), "N": (45, true), "O": (31, true), "P": (35, true),
            "Q": (12, true), "R": (15, true), "S": (1, true), "T": (17, true),
            "U": (32, true), "V": (9, true), "W": (13, true), "X": (7, true),
            "Y": (16, true), "Z": (6, true),
            
            // Numbers (no shift)
            "0": (29, false), "1": (18, false), "2": (19, false), "3": (20, false),
            "4": (21, false), "5": (23, false), "6": (22, false), "7": (26, false),
            "8": (28, false), "9": (25, false),
            
            // Special characters (no shift)
            " ": (49, false),
            "`": (50, false),
            "-": (27, false),
            "=": (24, false),
            "[": (33, false),
            "]": (30, false),
            "\\": (42, false),
            ";": (41, false),
            "'": (39, false),
            ",": (43, false),
            ".": (47, false),
            "/": (44, false),
            
            // Special characters (with shift)
            "~": (50, true),
            "!": (18, true),
            "@": (19, true),
            "#": (20, true),
            "$": (21, true),
            "%": (23, true),
            "^": (22, true),
            "&": (26, true),
            "*": (28, true),
            "(": (25, true),
            ")": (29, true),
            "_": (27, true),
            "+": (24, true),
            "{": (33, true),
            "}": (30, true),
            "|": (42, true),
            ":": (41, true),
            "\"": (39, true),
            "<": (43, true),
            ">": (47, true),
            "?": (44, true),
            
            // Control characters
            "\n": (36, false),
            "\t": (48, false),
        ]
        
        return keyMap[char]
    }
}
