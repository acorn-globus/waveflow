import Foundation
import AVFoundation
import WhisperKit

class TranscriptionManager: ObservableObject {
    @Published var transcribedText: String = ""
    @Published var isProcessing: Bool = false
    @Published var isInitialized: Bool = false
    
    private var audioRecorder: AVAudioRecorder?
    private var whisperKit: WhisperKit?
    private var tempURL: URL?
    
    init() {
        setupRecorder()
        Task {
            await setupWhisperKit()
        }
    }
    
    private func setupRecorder() {
        // Create temporary file URL for recording
        tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("recording.aiff")
        
        // Print the exact file path for debugging
        if let url = tempURL {
            print("Recording will be saved to: \(url.path)")
        }
        
        // Settings for AIFF format (well-supported on macOS)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        guard let url = tempURL else {
            print("Error creating temporary file URL")
            return
        }
        
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.prepareToRecord()
            print("Audio recorder setup completed successfully")
        } catch {
            print("Error creating audio recorder: \(error)")
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
        guard let recorder = audioRecorder,
              isInitialized else {
            print("Recorder not ready or not initialized")
            return
        }
        
        if recorder.record() {
            isProcessing = true
            print("Recording started successfully")
        } else {
            print("Failed to start recording")
        }
    }
    
    func stopRecording() {
        print("Stop recording called")
        audioRecorder?.stop()
        isProcessing = false
        
        // Print file information for debugging
        if let url = tempURL {
            do {
                let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64 ?? 0
                print("Recording stopped. File size: \(fileSize) bytes")
            } catch {
                print("Error getting file size: \(error)")
            }
        }
        
        Task {
            print("Starting transcription task")
            await transcribeRecording()
            print("Transcription task completed")
        }
    }
    
    private func transcribeRecording() async {
        guard let whisperKit = whisperKit,
              let url = tempURL else {
            print("Missing WhisperKit or URL")
            return
        }
        print("Starting transcription")
        
        do {
            let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64 ?? 0
            print("Attempting to transcribe file at: \(url.path)")
            print("File size before transcription: \(fileSize) bytes")
            
            if fileSize == 0 {
                print("Warning: File is empty!")
                return
            }
            
            let results = try await whisperKit.transcribe(
                audioPath: url.path,
                decodeOptions: .init()
            )
            let transcription = results.map { $0.text }.joined(separator: " ")
            print("Raw transcription results: \(results)")
            print("Processed transcription: \(transcription)")
            
            if !transcription.isEmpty {
                await MainActor.run {
                    self.transcribedText += transcription + " "
                }
            } else {
                print("Warning: Transcription was empty")
            }
        } catch {
            print("Error transcribing audio: \(error)")
        }
    }
}
