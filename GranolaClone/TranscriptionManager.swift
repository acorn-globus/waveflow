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
    private var audioFile: AVAudioFile?
    private var tempURL: URL?
    private var systemFormat: AVAudioFormat?
    private var micFormat: AVAudioFormat?
    private var recordingConfiguration: SCRecordingOutputConfiguration?
    
    
    init() {
        Task {
            await setupWhisperKit()
            await setupScreenCapture()
        }
    }
    
    private func setupScreenCapture() async {
        tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("recording.wav")
        
        streamOutput = ScreenCaptureStreamOutput(
            audioSampleHandler: { pcmBuffer in
                // Handle system audio samples here
                guard let url = self.tempURL else { return }
                print("Received audio samples")
                
                if self.audioFile == nil {
                    guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2) else {
                        print("Failed to create audio format")
                        return
                    }
                            
                    do {
                        self.audioFile = try AVAudioFile(forWriting: url, settings: format.settings)
                    } catch {
                        print("Error creating audio file: \(error)")
                        return
                    }
                }

                do {
                    try self.audioFile?.write(from: pcmBuffer)
                } catch {
                    print("Error writing audio buffer: \(error)")
                }
            },
            microphoneHandler: { pcmBuffer in
                // Handle microphone audio samples here
                guard let url = self.tempURL else { return }
                print("Received microphone input")
                
                if self.audioFile == nil {
                    guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2) else {
                        print("Failed to create audio format")
                        return
                    }
                            
                    do {
                        self.audioFile = try AVAudioFile(forWriting: url, settings: format.settings)
                    } catch {
                        print("Error creating audio file: \(error)")
                        return
                    }
                }

                do {
                    try self.audioFile?.write(from: pcmBuffer)
                } catch {
                    print("Error writing audio buffer: \(error)")
                }
            }
        )
        
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

            // Set up audio configuration
            configuration.sampleRate = 48000
            configuration.channelCount = 2
            
            stream = SCStream(filter: filter, configuration: configuration, delegate: streamOutput! as? SCStreamDelegate)
            
            try stream?.addStreamOutput(streamOutput!, type: .audio, sampleHandlerQueue: audioSampleBufferQueue)
            try stream?.addStreamOutput(streamOutput!, type: .microphone, sampleHandlerQueue: micSampleBufferQueue)
            
            
            let recordingURL = FileManager.default.temporaryDirectory.appendingPathComponent("recording_2.mov")
            recordingConfiguration = SCRecordingOutputConfiguration()
            recordingConfiguration?.outputURL = recordingURL
            recordingConfiguration?.outputFileType = .mov

            let recordingDelegate = RecordingOutput()
            let recordingOutput = SCRecordingOutput(configuration: recordingConfiguration!, delegate: recordingDelegate)

            try stream?.addRecordingOutput(recordingOutput)
            
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

class RecordingOutput: NSObject, SCRecordingOutputDelegate {
    override init() {
        super.init()
    }
}

@available(macOS 15.0, *)
class ScreenCaptureStreamOutput: NSObject, SCStreamOutput {
    // Closure types for handling different output types
    typealias AudioSampleHandler = (AVAudioPCMBuffer) -> Void
    typealias MicrophoneHandler = (AVAudioPCMBuffer) -> Void
    
    // Handlers for different types of output
    private var audioSampleHandler: AudioSampleHandler?
    private var microphoneHandler: MicrophoneHandler?
    
    init(audioSampleHandler: AudioSampleHandler? = nil,
         microphoneHandler: MicrophoneHandler? = nil) {
        self.audioSampleHandler = audioSampleHandler
        self.microphoneHandler = microphoneHandler
        super.init()
    }
    
    // SCStreamOutput protocol implementation
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }
        
        switch outputType {
        case .audio:
            handleAudio(for: sampleBuffer)
        case .microphone:
            handleMicrophone(for: sampleBuffer)
        case .screen:
            break
        @unknown default:
            break
        }
    }
    
    // Process audio sample buffers
    private func handleAudio(for buffer: CMSampleBuffer) {
        processAudioBuffer(buffer, handler: audioSampleHandler)
    }
    
    private func handleMicrophone(for buffer: CMSampleBuffer) {
        processAudioBuffer(buffer, handler: microphoneHandler)
    }
    
    private func processAudioBuffer(_ buffer: CMSampleBuffer, handler: ((AVAudioPCMBuffer) -> Void)?) {
        do {
            try buffer.withAudioBufferList { audioBufferList, blockBuffer in
                guard let description = buffer.formatDescription?.audioStreamBasicDescription,
                      let format = AVAudioFormat(standardFormatWithSampleRate: description.mSampleRate,
                                               channels: description.mChannelsPerFrame),
                      let samples = AVAudioPCMBuffer(pcmFormat: format,
                                                   bufferListNoCopy: audioBufferList.unsafePointer)
                else { return }
                
                handler?(samples)
            }
        } catch {
            print("Error processing audio buffer: \(error)")
        }
    }
}
