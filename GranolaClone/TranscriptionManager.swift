import Foundation
import AVFoundation
import WhisperKit
import ScreenCaptureKit
import AVFAudio
import CoreMedia

@available(macOS 15.0, *)
class TranscriptionManager: ObservableObject {
    @Published var transcribedText: String = ""
    @Published var isProcessing: Bool = false
    @Published var isInitialized: Bool = false
    @Published var availableMicrophones: [AVCaptureDevice] = []
    @Published var selectedMicrophoneID: String? = nil
    @Published var microphoneLevel: Float = 0.0
    
    private var whisperKit: WhisperKit?
    private var stream: SCStream?
    private var streamOutput: ScreenCaptureStreamOutput?
    private let audioSampleBufferQueue = DispatchQueue(label: "audio-sample-buffer-queue")
    private let micSampleBufferQueue = DispatchQueue(label: "mic-sample-buffer-queue")
    private var recordingOutput: SCRecordingOutput?
    private var recordingDelegate: RecordingDelegate?
    private var recordingURL: URL?
    
    init() {
        Task {
            await setupWhisperKit()
            await setupScreenCapture()
        }
    }
    
    private func setupScreenCapture() async {
        recordingURL = FileManager.default.temporaryDirectory.appendingPathComponent("recording.mov")
        streamOutput = ScreenCaptureStreamOutput()
        
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let display = content.displays.first!
            
            let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            
            let configuration = SCStreamConfiguration()
            configuration.capturesAudio = true
            configuration.excludesCurrentProcessAudio = false
            configuration.captureMicrophone = true
            configuration.microphoneCaptureDeviceID = AVCaptureDevice.default(for: .audio)?.uniqueID
            configuration.queueDepth = 5
            configuration.sampleRate = 48000
            configuration.channelCount = 2
            
            stream = SCStream(filter: filter, configuration: configuration, delegate: streamOutput)
            
            try stream?.addStreamOutput(streamOutput!, type: .audio, sampleHandlerQueue: audioSampleBufferQueue)
            try stream?.addStreamOutput(streamOutput!, type: .microphone, sampleHandlerQueue: micSampleBufferQueue)
            
            // Set up recording configuration
            let recordingConfig = SCRecordingOutputConfiguration()
            recordingConfig.outputURL = recordingURL!
            recordingConfig.outputFileType = .mov
            
            // Create recording delegate and output
            recordingDelegate = RecordingDelegate()
            recordingOutput = SCRecordingOutput(configuration: recordingConfig, delegate: recordingDelegate!)
            
            try stream?.addRecordingOutput(recordingOutput!)
            
            print("Screen capture setup completed successfully")
        } catch {
            print("Error setting up screen capture: \(error)")
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
        guard isInitialized else {
            print("WhisperKit not initialized")
            return
        }
        
        // Delete existing recording if any
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        
        stream?.startCapture()
        isProcessing = true
        print("Recording started successfully")
    }
    
    func stopRecording() {
        print("Stop recording called")
        stream?.stopCapture()
        isProcessing = false
        
        Task {
            print("Starting transcription task")
            await transcribeRecording()
            print("Transcription task completed")
        }
    }
    
    private func convertMovToWav(inputURL: URL) async throws -> URL {
        let wavURL = FileManager.default.temporaryDirectory.appendingPathComponent("converted_audio.wav")
        
        // Delete existing WAV file if any
        try? FileManager.default.removeItem(at: wavURL)
        
        let asset = AVAsset(url: inputURL)
        let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A)!
        
        exportSession.outputURL = wavURL
        exportSession.outputFileType = .wav
        exportSession.shouldOptimizeForNetworkUse = true
        
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            throw NSError(domain: "TranscriptionManager",
                         code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to convert MOV to WAV"])
        }
        
        return wavURL
    }
    
    private func transcribeRecording() async {
        guard let whisperKit = whisperKit,
              let movURL = recordingURL else {
            print("Missing WhisperKit or recording URL")
            return
        }
        
        do {
            print("Converting MOV to WAV")
            let wavURL = try await convertMovToWav(inputURL: movURL)
            
            let fileSize = try FileManager.default.attributesOfItem(atPath: wavURL.path)[.size] as? UInt64 ?? 0
            print("Attempting to transcribe WAV file at: \(wavURL.path)")
            print("File size before transcription: \(fileSize) bytes")
            
            if fileSize == 0 {
                print("Warning: File is empty!")
                return
            }
            
            let results = try await whisperKit.transcribe(
                audioPath: wavURL.path,
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
            
            // Clean up temporary WAV file
            try? FileManager.default.removeItem(at: wavURL)
            
        } catch {
            print("Error in transcription process: \(error)")
        }
    }
}

class RecordingDelegate: NSObject, SCRecordingOutputDelegate {
    override init() {
        super.init()
    }
}

@available(macOS 15.0, *)
class ScreenCaptureStreamOutput: NSObject, SCStreamOutput, SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("Stream stopped with error: \(error)")
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        // We don't need to handle the audio buffers manually anymore since we're using SCRecordingOutput
    }
}
