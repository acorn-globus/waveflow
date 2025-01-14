import Foundation
import AVFoundation
import WhisperKit
import ScreenCaptureKit

@available(macOS 15.0, *)
class TranscriptionManager: ObservableObject {
    @Published var transcribedText: String = ""
    @Published var isProcessing: Bool = false
    @Published var isInitialized: Bool = false
    
    private var whisperKit: WhisperKit?
    private var stream: SCStream?
    private var streamOutput: CaptureEngineStreamOutput?
    private let audioSampleBufferQueue = DispatchQueue(label: "audio-sample-buffer-queue")
    private var audioFile: AVAudioFile?
    private var tempURL: URL?
    
    init() {
        Task {
            await setupWhisperKit()
            await setupScreenCapture()
        }
    }
    
    private func setupScreenCapture() async {
        // Create temporary file URL for recording
        tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("recording.wav")
        
        // Setup stream output handler
        streamOutput = CaptureEngineStreamOutput { [weak self] sampleBuffer in
            self?.processAudioBuffer(sampleBuffer)
        }
        
        do {
            // Get shareable content
            let content = try await SCShareableContent.current
            let display = content.displays.first!
            
            // Create a filter for audio only
            let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            
            // Configure stream for audio capture
            let configuration = SCStreamConfiguration()
            configuration.capturesAudio = true
            configuration.excludesCurrentProcessAudio = false  // Include system audio
            configuration.captureMicrophone = true  // Include microphone
            
            // Create and start the stream
            stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
            
            // Add audio outputs
            try stream?.addStreamOutput(streamOutput!, type: .audio, sampleHandlerQueue: audioSampleBufferQueue)
            try stream?.addStreamOutput(streamOutput!, type: .microphone, sampleHandlerQueue: audioSampleBufferQueue)
            
        } catch {
            print("Error setting up screen capture: \(error)")
        }
    }
    
    private func processAudioBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let url = tempURL else { return }
        
        // If this is the first buffer, create the audio file
        if audioFile == nil {
            guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2) else {
                print("Failed to create audio format")
                return
            }
            
            do {
                audioFile = try AVAudioFile(forWriting: url, settings: format.settings)
            } catch {
                print("Error creating audio file: \(error)")
                return
            }
        }
        
        // Convert CMSampleBuffer to PCM buffer and write to file
        do {
            try sampleBuffer.withAudioBufferList { audioBufferList, blockBuffer in
                guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2),
                      let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: audioBufferList.unsafePointer)
                else { return }
                
                try audioFile?.write(from: pcmBuffer)
            }
        } catch {
            print("Error writing audio buffer: \(error)")
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
        
        stream?.startCapture()
        isProcessing = true
        print("Recording started successfully")

    }
    
    func stopRecording() {
        print("Stop recording called")
        stream?.stopCapture()
        audioFile = nil  // Close the current audio file
        isProcessing = false
        
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

// Stream output handler class
@available(macOS 15.0, *)
class CaptureEngineStreamOutput: NSObject, SCStreamOutput {
    var sampleBufferHandler: ((CMSampleBuffer) -> Void)?
    
    init(sampleBufferHandler: ((CMSampleBuffer) -> Void)? = nil) {
        self.sampleBufferHandler = sampleBufferHandler
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio || type == .microphone else { return }
        sampleBufferHandler?(sampleBuffer)
    }
}
