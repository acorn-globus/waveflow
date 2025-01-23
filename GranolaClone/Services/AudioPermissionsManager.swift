import AVFoundation
import SwiftUI
import CoreAudio
import Foundation

@MainActor
class AudioPermissionsManager: ObservableObject {
    @Published var microphonePermissionGranted = false
    @Published var systemAudioPermissionGranted = false
    
    private var audioSession: AVCaptureSession?
    
    init() {
        checkMicrophonePermissions()
        checkSystemAudioPermissions()
    }
    
    func checkMicrophonePermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            microphonePermissionGranted = true
        default:
            microphonePermissionGranted = false
        }
    }
    
    func checkSystemAudioPermissions() {
        // Check if we can access system audio device
        let screenPermission = CGPreflightScreenCaptureAccess()
        if screenPermission {
            systemAudioPermissionGranted = true
        }
    }
    
    func requestMicrophonePermission() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                self?.microphonePermissionGranted = granted
            }
        }
    }
    
    func requestSystemAudioPermission() {
        CGRequestScreenCaptureAccess()
    }
}
