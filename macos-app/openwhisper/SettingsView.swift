//
//  SettingsView.swift
//  openwhisper
//
//  Created by Connor on 13/1/2026.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    @State private var isCapturingKey = false
    @State private var showAuthKey = false
    
    var body: some View {
        Form {
            Section(header: Text("API Configuration")) {
                TextField("API URL", text: $settings.apiUrl)
                    .textFieldStyle(.roundedBorder)
                
                HStack {
                    if showAuthKey {
                        TextField("Authorization Key", text: $settings.authorizationKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("Authorization Key", text: $settings.authorizationKey)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Button(action: { showAuthKey.toggle() }) {
                        Image(systemName: showAuthKey ? "eye.slash" : "eye")
                    }
                }
            }
            
            Section(header: Text("Appearance")) {
                Picker("Theme", selection: $settings.theme) {
                    ForEach(ThemeOption.allCases, id: \.self) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Section(header: Text("Hotkey Configuration")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Modifier Key:")
                        Picker("", selection: $settings.modifierKey) {
                            ForEach(ModifierKey.allCases, id: \.self) { key in
                                Text(key.rawValue).tag(key)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 120)
                    }
                    
                    HStack {
                        Text("Second Key:")
                        Button(action: {
                            isCapturingKey = true
                        }) {
                            Text(settings.secondKey)
                                .frame(minWidth: 80)
                                .padding(6)
                                .background(isCapturingKey ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        
                        if isCapturingKey {
                            Text("Press any key...")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    Text("Current: \(settings.modifierKey.rawValue) + \(settings.secondKey)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section {
                HStack {
                    Spacer()
                    Button("Save & Apply") {
                        applyHotkey()
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 450)
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if isCapturingKey {
                    if let characters = event.charactersIgnoringModifiers?.uppercased() {
                        settings.secondKey = characters
                    } else {
                        // Handle special keys
                        switch Int(event.keyCode) {
                        case 49: settings.secondKey = "Space"
                        case 36: settings.secondKey = "Return"
                        case 48: settings.secondKey = "Tab"
                        case 51: settings.secondKey = "Delete"
                        case 53: settings.secondKey = "Escape"
                        case 123: settings.secondKey = "Left"
                        case 124: settings.secondKey = "Right"
                        case 125: settings.secondKey = "Down"
                        case 126: settings.secondKey = "Up"
                        default: break
                        }
                    }
                    isCapturingKey = false
                    return nil
                }
                return event
            }
        }
    }
    
    private func applyHotkey() {
        HotkeyManager.shared.registerHotKey(
            modifierKey: settings.modifierKey,
            secondKey: settings.secondKey
        )
    }
}

#Preview {
    SettingsView()
}
