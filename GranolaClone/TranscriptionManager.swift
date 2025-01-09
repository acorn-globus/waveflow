import Foundation
import AVFoundation
import WhisperKit

class TranscriptionManager: ObservableObject {
    @Published var transcribedText: String = ""
    @Published var isProcessing: Bool = false
    @Published var isInitialized: Bool = false
    
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var inputNode: AVAudioInputNode?
    private var whisperKit: WhisperKit?
    private var tempURL: URL?
    
    init() {
        setupAudioEngine()
        Task {
            await setupWhisperKit()
        }
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode
        
        // Create temporary file URL for recording
        tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("recording.wav")
        
        // Get the native format from the input node
        guard let inputFormat = inputNode?.outputFormat(forBus: 0) else {
            print("Error getting input format")
            return
        }
        
        print("Input format: \(inputFormat)")
        
        guard let url = tempURL else {
            print("Error creating temporary file URL")
            return
        }
        
        // Create audio file
        do {
            audioFile = try AVAudioFile(
                forWriting: url,
                settings: inputFormat.settings
            )
        } catch {
            print("Error creating audio file: \(error)")
            return
        }
        
        inputNode?.installTap(
            onBus: 0,
            bufferSize: 4096,  // Increased buffer size for better performance
            format: inputFormat
        ) { [weak self] buffer, time in
            self?.writeBufferToFile(buffer)
        }
    }
    
    private func writeBufferToFile(_ buffer: AVAudioPCMBuffer) {
        guard let audioFile = audioFile else { return }
        
        do {
            try audioFile.write(from: buffer)
        } catch {
            print("Error writing buffer to file: \(error)")
        }
    }
    
    private func setupWhisperKit() async {
        do {
            whisperKit = try await WhisperKit()
            await MainActor.run {
                isInitialized = true
            }
        } catch {
            print("Error initializing WhisperKit: \(error)")
        }
    }
    
    func startRecording() {
        guard let audioEngine = audioEngine,
              let url = tempURL,
              isInitialized else { return }
        
        // Reset audio file for new recording
        do {
            let format = audioEngine.inputNode.outputFormat(forBus: 0)
            audioFile = try AVAudioFile(
                forWriting: url,
                settings: format.settings
            )
            
            try audioEngine.start()
            isProcessing = true
        } catch {
            print("Error starting recording: \(error)")
        }
    }
    
    func stopRecording() {
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        isProcessing = false
        
        // Transcribe the recorded file
        Task {
            await transcribeRecording()
        }
    }
    
    private func transcribeRecording() async {
        guard let whisperKit = whisperKit,
              let url = tempURL else { return }
        
        do {
            if let transcription = try await whisperKit.transcribe(audioPath: url.path)?.text {
                await MainActor.run {
                    self.transcribedText += transcription + " "
                }
            }
        } catch {
            print("Error transcribing audio: \(error)")
        }
    }
}
