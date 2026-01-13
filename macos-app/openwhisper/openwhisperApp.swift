//
//  openwhisperApp.swift
//  openwhisper
//
//  Created by Connor on 13/1/2026.
//

import SwiftUI
import AppKit
import AVFoundation

@main
struct openwhisperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var settingsWindow: NSWindow?
    var hudWindowController: HUDWindowController?
    let audioRecorder = AudioRecorder()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 App launched")
        
        // Keep app in background (LSUIElement handles this but we reinforce it)
        NSApp.setActivationPolicy(.accessory)
        
        setupMenuBar()
        showSettingsWindow()
        requestPermissions()
        setupHotkey()
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        print("❌ Prevented termination - app stays in menu bar")
        return .terminateCancel
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func setupMenuBar() {
        print("📍 Setting up menu bar")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "OpenWhisper")
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }
        print("✅ Menu bar icon created")
    }
    
    func requestPermissions() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.requestMicrophonePermission()
            self.requestAccessibilityPermission()
        }
    }
    
    func requestMicrophonePermission() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            print("🎤 Microphone permission: \(granted)")
            if !granted {
                DispatchQueue.main.async {
                    self.showPermissionAlert(
                        title: "Microphone Access Required",
                        message: "OpenWhisper needs microphone access to record audio for transcription. Please grant access in System Settings → Privacy & Security → Microphone."
                    )
                }
            }
        }
    }
    
    func requestAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        print("♿ Accessibility permission: \(trusted)")
        
        if !trusted {
            // Try to enable accessibility API
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
            let enabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
            print("♿ After prompt - Accessibility enabled: \(enabled)")

            if !enabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.showPermissionAlert(
                        title: "Accessibility Access Required",
                        message: "OpenWhisper needs accessibility access for:\n\n• Global hotkey detection\n• Automatic text typing\n\nPlease grant access in System Settings → Privacy & Security → Accessibility, then restart the app."
                    )

                    let prefpaneUrl = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                    NSWorkspace.shared.open(prefpaneUrl)
                }
            }
        }
    }
    
    func showPermissionAlert(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    func showErrorNotification(title: String, message: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    @objc func statusBarButtonClicked() {
        print("🖱️ Menu bar icon clicked")
        showSettingsWindow()
    }
    
    func showSettingsWindow() {
        print("🪟 Showing settings window")
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 450),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "OpenWhisper Settings"
            window.center()
            window.contentView = NSHostingView(rootView: SettingsView())
            window.delegate = self
            settingsWindow = window
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    
    func setupHotkey() {
        print("⌨️ Setting up hotkey")
        let settings = SettingsManager.shared
        
        HotkeyManager.shared.onHotKeyPressed = { [weak self] in
            DispatchQueue.main.async {
                self?.startRecording()
            }
        }
        
        HotkeyManager.shared.onHotKeyReleased = { [weak self] in
            DispatchQueue.main.async {
                self?.stopRecording()
            }
        }
        
        HotkeyManager.shared.registerHotKey(
            modifierKey: settings.modifierKey,
            secondKey: settings.secondKey
        )
    }
    
    func startRecording() {
        print("🎤 START RECORDING CALLED")
        if hudWindowController == nil {
            hudWindowController = HUDWindowController(audioRecorder: audioRecorder)
        }
        
        hudWindowController?.show()
        audioRecorder.startRecording()
        print("🎤 Recording started, isRecording: \(audioRecorder.isRecording)")
    }
    
    func stopRecording() {
        print("⏹️ STOP RECORDING CALLED")

        audioRecorder.stopRecording { base64Audio, audioFileURL in
            print("📦 stopRecording callback - hasAudio: \(base64Audio != nil), hasURL: \(audioFileURL != nil)")
            
            guard let base64Audio = base64Audio else {
                print("❌ No audio data received")
                if let url = audioFileURL {
                    try? FileManager.default.removeItem(at: url)
                }
                self.hudWindowController?.hide()
                return
            }
            
            print("✅ Got base64 audio, length: \(base64Audio.count)")
            let settings = SettingsManager.shared
            
            // Show loading state
            DispatchQueue.main.async {
                self.audioRecorder.isLoading = true
            }

            print("🌐 Sending to API: \(settings.apiUrl)")
            APIService.shared.sendTranscriptionRequest(
                audioBase64: base64Audio,
                apiUrl: settings.apiUrl,
                authToken: settings.authorizationKey
            ) { result in
                if let url = audioFileURL {
                    try? FileManager.default.removeItem(at: url)
                    print("🗑️ Deleted temp file")
                }
                
                // Hide loading state and hide the HUD
                DispatchQueue.main.async {
                    self.audioRecorder.isLoading = false
                    self.hudWindowController?.hide()
                }

                switch result {
                case .success(let response):
                    print("✅ API Response: \(response)")
                    // Check accessibility before attempting to type
                    let isTrusted = AXIsProcessTrusted()
                    print("♿ Accessibility trusted before typing: \(isTrusted)")

                    if !isTrusted {
                        self.showErrorNotification(
                            title: "Accessibility Permission Missing",
                            message: "OpenWhisper has lost accessibility permission. Please restart the app and grant accessibility access in System Settings → Privacy & Security → Accessibility."
                        )
                        return
                    }

                    if let data = response.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let transcript = json["transcript"] as? String {
                        print("⌨️ Typing transcript: \(transcript)")
                        TextTyper.shared.typeText(transcript)
                    } else {
                        print("❌ Failed to parse transcript")
                        self.showErrorNotification(
                            title: "Transcription Failed",
                            message: "Unable to parse the transcription response from the server."
                        )
                    }
                case .failure(let error):
                    print("❌ API Error: \(error)")
                    self.showErrorNotification(
                        title: "Connection Error",
                        message: "Failed to connect to the transcription service:\n\n\(error.localizedDescription)"
                    )
                }
            }
        }
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        print("🪟 Window closing")
        NSApp.setActivationPolicy(.accessory)
        
        if let window = notification.object as? NSWindow {
            if window == settingsWindow {
                settingsWindow = nil
            }
        }
    }
}
