import Foundation
import AVFoundation
import WhisperKit
import ScreenCaptureKit

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
    private var streamOutput: CaptureEngineStreamOutput?
    private let audioSampleBufferQueue = DispatchQueue(label: "audio-sample-buffer-queue")
    private var audioFile: AVAudioFile?
    private var tempURL: URL?
    private var systemFormat: AVAudioFormat?
    private var micFormat: AVAudioFormat?
    
    init() {
        Task {
            await setupWhisperKit()
            await setupScreenCapture()
        }
    }
    
    private func setupScreenCapture() async {
        // Get available microphones
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        ).devices
        
        await MainActor.run {
            self.availableMicrophones = devices
            // Select the default microphone if available and not already selected
            if selectedMicrophoneID == nil {
                self.selectedMicrophoneID = devices.first?.uniqueID
            }
        }
        
        print("Available microphones: \(devices.map { "\($0.localizedName): \($0.uniqueID)" })")
        
        tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("recording.wav")
        
        streamOutput = CaptureEngineStreamOutput { [weak self] sampleBuffer, type in
            self?.processAudioBuffer(sampleBuffer, type: type)
        }
        
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let display = content.displays.first!
            
            let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            
            let configuration = SCStreamConfiguration()
            configuration.capturesAudio = true
            configuration.captureMicrophone = true
            
            // Set the selected microphone device ID
            if let micID = selectedMicrophoneID {
                configuration.microphoneCaptureDeviceID = micID
                print("Configured microphone with ID: \(micID)")
            }
            
            // Set up audio configuration
            configuration.sampleRate = 48000
            configuration.channelCount = 2
            
            stream = SCStream(filter: filter, configuration: configuration, delegate: streamOutput!)
            
            try stream?.addStreamOutput(streamOutput!, type: .audio, sampleHandlerQueue: audioSampleBufferQueue)
            try stream?.addStreamOutput(streamOutput!, type: .microphone, sampleHandlerQueue: audioSampleBufferQueue)
            
            print("Screen capture setup completed successfully")
        } catch {
            print("Error setting up screen capture: \(error)")
        }
    }
    
    private func createAudioFormat(for sampleBuffer: CMSampleBuffer, type: SCStreamOutputType) -> AVAudioFormat? {
        guard let formatDescription = sampleBuffer.formatDescription,
              let streamBasicDescription = formatDescription.audioStreamBasicDescription else {
            print("Failed to get audio format description")
            return nil
        }
        
        // Create format based on the type
        let channelCount: AVAudioChannelCount = (type == .audio) ? 2 : 1
        
        return AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: streamBasicDescription.mSampleRate,
            channels: channelCount,
            interleaved: false
        )
    }
    
    private func processAudioBuffer(_ sampleBuffer: CMSampleBuffer, type: SCStreamOutputType) {
        print("Processing \(type) buffer with \(CMSampleBufferGetNumSamples(sampleBuffer)) samples")
        
        guard let url = tempURL else { return }
        
        // Initialize audio file if needed
        if audioFile == nil {
            // Create format based on the first received buffer
            let format = createAudioFormat(for: sampleBuffer, type: type)
            guard let format = format else {
                print("Failed to create audio format")
                return
            }
            
            if type == .audio {
                systemFormat = format
                print("System audio format created: \(format)")
            } else {
                micFormat = format
                print("Microphone format created: \(format)")
            }
            
            do {
                // Create audio file with explicit settings for mixed audio
                let settings: [String: Any] = [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: format.sampleRate,
                    AVNumberOfChannelsKey: 2,
                    AVLinearPCMBitDepthKey: 32,
                    AVLinearPCMIsFloatKey: true,
                    AVLinearPCMIsNonInterleaved: true
                ]
                
                audioFile = try AVAudioFile(forWriting: url, settings: settings)
                print("Created audio file with format: \(format)")
            } catch {
                print("Error creating audio file: \(error)")
                return
            }
        }
        
        // Convert and write buffer
        do {
            try sampleBuffer.withAudioBufferList { audioBufferList, blockBuffer in
                let format = (type == .audio) ? systemFormat : micFormat
                guard let format = format,
                      let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: audioBufferList.unsafePointer)
                else { return }
                
                if type == .microphone {
                    guard let stereoBuffer = convertMonoToStereo(pcmBuffer) else { return }
                    try audioFile?.write(from: stereoBuffer)
                    print("Wrote microphone buffer with \(stereoBuffer.frameLength) frames")
                } else {
                    try audioFile?.write(from: pcmBuffer)
                    print("Wrote system audio buffer with \(pcmBuffer.frameLength) frames")
                }
            }
        } catch {
            print("Error writing audio buffer: \(error), type: \(type)")
        }
    }
    
    private func convertMonoToStereo(_ monoBuffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let stereoFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: monoBuffer.format.sampleRate,
            channels: 2,
            interleaved: false
        ),
        let stereoBuffer = AVAudioPCMBuffer(
            pcmFormat: stereoFormat,
            frameCapacity: monoBuffer.frameLength
        ) else {
            return nil
        }
        
        // Copy mono data to both channels of stereo buffer
        let monoData = monoBuffer.floatChannelData?[0]
        let leftData = stereoBuffer.floatChannelData?[0]
        let rightData = stereoBuffer.floatChannelData?[1]
        
        for frame in 0..<Int(monoBuffer.frameLength) {
            leftData?[frame] = monoData?[frame] ?? 0
            rightData?[frame] = monoData?[frame] ?? 0
        }
        
        stereoBuffer.frameLength = monoBuffer.frameLength
        return stereoBuffer
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
        if let url = tempURL {
            try? FileManager.default.removeItem(at: url)
        }
        
        // Reset audio file
        audioFile = nil
        
        stream?.startCapture()
        isProcessing = true
        print("Recording started successfully")
    }
    
    func stopRecording() {
        print("Stop recording called")
        stream?.stopCapture()
        audioFile = nil
        isProcessing = false
        
        Task {
            print("Starting transcription task")
            await transcribeRecording()
            print("Transcription task completed")
        }
    }
    
    func selectMicrophone(withID id: String) async {
        print("Selecting microphone with ID: \(id)")
        selectedMicrophoneID = id
        // Recreate the stream with the new microphone
        await setupScreenCapture()
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

@available(macOS 15.0, *)
class CaptureEngineStreamOutput: NSObject, SCStreamOutput, SCStreamDelegate {
    var sampleBufferHandler: ((CMSampleBuffer, SCStreamOutputType) -> Void)?
    
    init(sampleBufferHandler: ((CMSampleBuffer, SCStreamOutputType) -> Void)? = nil) {
        self.sampleBufferHandler = sampleBufferHandler
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio || type == .microphone else { return }
        sampleBufferHandler?(sampleBuffer, type)
    }
    
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("Stream stopped with error: \(error)")
    }
}


