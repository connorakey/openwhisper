//
//  AudioRecorder.swift
//  openwhisper
//
//  Created by Connor on 13/1/2026.
//

import Foundation
import AVFoundation
import Combine

class AudioRecorder: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var levelTimer: Timer?
    
    @Published var isRecording = false
    @Published var isLoading = false
    @Published var audioLevel: Float = 0.0
    
    func startRecording() {
        NSLog("📱 AudioRecorder.startRecording() called")
        let tempDir = FileManager.default.temporaryDirectory
        recordingURL = tempDir.appendingPathComponent("recording_\(UUID().uuidString).m4a")
        
        NSLog("📁 Recording to: \(recordingURL!.path)")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.delegate = self
            
            let started = audioRecorder?.record() ?? false
            
            NSLog("🎙️ Record started: \(started)")
            
            if started {
                isRecording = true
                startMonitoringAudioLevel()
            } else {
                NSLog("❌ Failed to start recording")
            }
        } catch {
            NSLog("❌ Recording error: \(error)")
            isRecording = false
        }
    }
    
    func stopRecording(completion: @escaping (String?, URL?) -> Void) {
        levelTimer?.invalidate()
        levelTimer = nil
        
        audioRecorder?.stop()
        isRecording = false
        audioLevel = 0.0
        
        guard let url = recordingURL else {
            completion(nil, nil)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            Thread.sleep(forTimeInterval: 0.1)
            
            guard FileManager.default.fileExists(atPath: url.path) else {
                DispatchQueue.main.async {
                    completion(nil, nil)
                }
                return
            }
            
            do {
                let audioData = try Data(contentsOf: url)
                let base64String = audioData.base64EncodedString()
                
                DispatchQueue.main.async {
                    completion(base64String, url)
                }
            } catch {
                try? FileManager.default.removeItem(at: url)
                DispatchQueue.main.async {
                    completion(nil, nil)
                }
            }
        }
    }
    
    private func startMonitoringAudioLevel() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self, self.isRecording else {
                timer.invalidate()
                return
            }
            
            self.audioRecorder?.updateMeters()
            let power = self.audioRecorder?.averagePower(forChannel: 0) ?? -160
            // This makes the visualizer less sensitive and won't max out when speaking normally
            let normalizedPower = max(0, min(1, (power + 40) / 40))

            DispatchQueue.main.async {
                self.audioLevel = normalizedPower
            }
        }
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            isRecording = false
            audioLevel = 0.0
        }
    }
}
