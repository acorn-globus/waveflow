import Foundation
import AVFoundation
import WhisperKit

class TranscriptionManager: ObservableObject {
    @Published var transcribedText: String = ""
    @Published var isProcessing: Bool = false
    @Published var isInitialized: Bool = false
    
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var whisperKit: WhisperKit?
    
    private let bufferSize: AVAudioFrameCount = 1024
    private let sampleRate: Double = 16000
    
    init() {
        setupAudioEngine()
        Task {
            await setupWhisperKit()
        }
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode
        
        let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )
        
        guard let format = recordingFormat else {
            print("Error creating audio format")
            return
        }
        
        inputNode?.installTap(
            onBus: 0,
            bufferSize: bufferSize,
            format: format
        ) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }
    }
    
    private func setupWhisperKit() async {
        do {
            // Initialize WhisperKit with default settings
            whisperKit = try await WhisperKit()
            await MainActor.run {
                isInitialized = true
            }
        } catch {
            print("Error initializing WhisperKit: \(error)")
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let whisperKit = whisperKit else { return }
        
        Task {
            do {
                let result = try await whisperKit.transcribe(buffer)
                await MainActor.run {
                    self.transcribedText += result + " "
                }
            } catch {
                print("Error transcribing audio: \(error)")
            }
        }
    }
    
    func startRecording() {
        guard let audioEngine = audioEngine, isInitialized else { return }
        
        do {
            try audioEngine.start()
            isProcessing = true
        } catch {
            print("Error starting audio engine: \(error)")
        }
    }
    
    func stopRecording() {
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        isProcessing = false
    }
}
