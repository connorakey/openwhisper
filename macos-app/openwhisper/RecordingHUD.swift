//
//  RecordingHUD.swift
//  openwhisper
//
//  Created by Connor on 13/1/2026.
//

import SwiftUI

struct RecordingHUD: View {
    @ObservedObject var audioRecorder: AudioRecorder
    @State private var animationPhase: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Recording...")
                .font(.headline)
                .foregroundColor(.primary)
            
            AudioVisualizerView(audioLevel: audioRecorder.audioLevel, animationPhase: animationPhase, colorScheme: colorScheme)
                .frame(width: 300, height: 60)
            
            Text("Hold key to record")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        )
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                animationPhase = 1
            }
        }
    }
}

struct AudioVisualizerView: View {
    let audioLevel: Float
    let animationPhase: CGFloat
    let colorScheme: ColorScheme
    private let barCount = 40
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                VisualizerBar(
                    index: index,
                    barCount: barCount,
                    audioLevel: audioLevel,
                    animationPhase: animationPhase,
                    colorScheme: colorScheme
                )
            }
        }
    }
}

struct VisualizerBar: View {
    let index: Int
    let barCount: Int
    let audioLevel: Float
    let animationPhase: CGFloat
    let colorScheme: ColorScheme
    
    private var barHeight: CGFloat {
        let normalizedIndex = CGFloat(index) / CGFloat(barCount)
        let wave = sin((normalizedIndex + animationPhase) * .pi * 4)
        let baseHeight = 0.3 + abs(wave * 0.25)
        let audioComponent = CGFloat(audioLevel) * 0.8
        return min(baseHeight + audioComponent, 1.0)
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(colorScheme == .dark ? Color.white : Color.black)
            .frame(width: 5, height: max(10, 60 * barHeight))
    }
}

struct HUDWindow: View {
    @ObservedObject var audioRecorder: AudioRecorder
    
    var body: some View {
        RecordingHUD(audioRecorder: audioRecorder)
    }
}

class HUDWindowController {
    private var window: NSWindow?
    private let audioRecorder: AudioRecorder
    
    init(audioRecorder: AudioRecorder) {
        self.audioRecorder = audioRecorder
    }
    
    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 180),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .stationary]
            window.ignoresMouseEvents = false
            window.hasShadow = false
            
            let hostingView = NSHostingView(rootView: HUDWindow(audioRecorder: audioRecorder))
            window.contentView = hostingView
            
            positionAtBottom(window: window)
            self.window = window
        }
        
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }
    
    func hide() {
        window?.orderOut(nil)
    }
    
    private func positionAtBottom(window: NSWindow) {
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowWidth: CGFloat = 400
            let windowHeight: CGFloat = 180
            let xPos = screenFrame.midX - (windowWidth / 2)
            let yPos = screenFrame.minY + 100
            
            window.setFrame(NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight), display: true)
        }
    }
}
