import Foundation
import AVFoundation
import WhisperKit
import ScreenCaptureKit
import AVFAudio
import CoreMedia

@available(macOS 15.0, *)
class TranscriptionManager: ObservableObject {
    // Published properties for UI updates
    @Published var transcribedText: String = ""
    @Published var isProcessing: Bool = false
    @Published var isInitialized: Bool = false
    @Published var currentText: String = ""
    @Published var confirmedText: String = ""
    @Published var hypothesisText: String = ""
    
    // Real-time transcription state
    private var lastBufferSize: Int = 0
    private var currentFallbacks: Int = 0
    private var lastAgreedSeconds: Float = 0.0
    private var prevResult: TranscriptionResult?
    private var prevWords: [WordTiming] = []
    private var lastAgreedWords: [WordTiming] = []
    private var confirmedWords: [WordTiming] = []
    private var hypothesisWords: [WordTiming] = []
    private var eagerResults: [TranscriptionResult?] = []
    
    // Configuration
    private let tokenConfirmationsNeeded: Int = 2
    private let compressionCheckWindow: Int = 20
    private let silenceThreshold: Float = 0.3
    private let useVAD: Bool = true
    
    // Core components
    private var whisperKit: WhisperKit?
    private var stream: SCStream?
    private var streamOutput: ScreenCaptureStreamOutput?
    private let audioSampleBufferQueue = DispatchQueue(label: "audio-sample-buffer-queue")
    private let micSampleBufferQueue = DispatchQueue(label: "mic-sample-buffer-queue")
    
    init() {
        Task {
            await setupWhisperKit()
            await setupScreenCapture()
        }
    }
    
    private func setupScreenCapture() async {
        streamOutput = ScreenCaptureStreamOutput(
            audioSampleHandler: { pcmBuffer in
                print("Received audio samples")
                Task {
                    await self.transcribeBuffer(Array(_immutableCocoaArray: pcmBuffer))
                }
            },
            microphoneHandler: { pcmBuffer in
//                print("Received microphone input")
//                Task {
//                    await self.transcribeBuffer(Array(_immutableCocoaArray: pcmBuffer))
//                }
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
            
            configuration.sampleRate = 48000
            configuration.channelCount = 2
            
            stream = SCStream(filter: filter, configuration: configuration, delegate: streamOutput! as? SCStreamDelegate)
            
            try stream?.addStreamOutput(streamOutput!, type: .audio, sampleHandlerQueue: audioSampleBufferQueue)
            try stream?.addStreamOutput(streamOutput!, type: .microphone, sampleHandlerQueue: micSampleBufferQueue)
            
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
        
        resetTranscriptionState()
        stream?.startCapture()
        isProcessing = true
        print("Recording started successfully")
    }
    
    func stopRecording() {
        print("Stop recording called")
        stream?.stopCapture()
        isProcessing = false
    }
    
    private func transcribeBuffer(_ samples: [Float]) async {
        guard let whisperKit = whisperKit else {
            print("Missing WhisperKit")
            return
        }
        
        // Calculate buffer metrics
        let nextBufferSize = samples.count - lastBufferSize
        let nextBufferSeconds = Float(nextBufferSize) / Float(WhisperKit.sampleRate)
        print("Buffer metrics - size: \(nextBufferSize), seconds: \(nextBufferSeconds)")
        
        // Only process if we have at least 1 second of new audio
        guard nextBufferSeconds > 1 else {
            await MainActor.run {
                if currentText.isEmpty {
                    currentText = "Waiting for speech..."
                }
            }
            return
        }
        
        // Voice Activity Detection
        if useVAD {
            let averageEnergy = calculateBufferEnergy(samples)
            let voiceDetected = averageEnergy > silenceThreshold
            print("VAD - energy: \(averageEnergy), voice detected: \(voiceDetected)")
            
            guard voiceDetected else {
                await MainActor.run {
                    if currentText.isEmpty {
                        currentText = "Waiting for speech..."
                    }
                }
                return
            }
        }
        
        // Store this for next iteration's calculations
        lastBufferSize = samples.count
        
        do {
            let options = DecodingOptions(
                verbose: true,  // Enable for debugging
                temperature: 0.0,
                temperatureFallbackCount: 5,
                sampleLength: 224,
                usePrefillPrompt: true,
                usePrefillCache: true,
                skipSpecialTokens: false,
                wordTimestamps: true,
                clipTimestamps: [lastAgreedSeconds],
                prefixTokens: lastAgreedWords.flatMap { $0.tokens },
                firstTokenLogProbThreshold: -1.5
            )
            
            // Callback for monitoring transcription progress
            let decodingCallback: ((TranscriptionProgress) -> Bool?) = { progress in
                Task { @MainActor in
                    let fallbacks = Int(progress.timings.totalDecodingFallbacks)
                    if progress.text.count < self.currentText.count && fallbacks != self.currentFallbacks {
                        print("Fallback occurred: \(fallbacks)")
                    }
                    self.currentText = progress.text
                    self.currentFallbacks = fallbacks
                    print("Progress update - text: \(progress.text)")
                }
                
                // Check for early stopping conditions
                let currentTokens = progress.tokens
                if currentTokens.count > self.compressionCheckWindow {
                    let checkTokens = Array(currentTokens.suffix(self.compressionCheckWindow))
                    if self.compressionRatio(of: checkTokens) > options.compressionRatioThreshold ?? 0.5 {
                        return false
                    }
                }
                
                if progress.avgLogprob ?? 0 < options.logProbThreshold ?? -1.0 {
                    return false
                }
                
                return nil
            }
            
            print("Starting transcription with buffer size: \(samples.count)")
            let transcription: TranscriptionResult? = try await whisperKit.transcribe(
                audioArray: samples,
                decodeOptions: options,
                callback: decodingCallback
            )
            print("Transcription completed")
            
            // Update UI with results
            await MainActor.run {
                if let result = transcription {
                    print("Processing result: \(result.text)")
                    // Filter words that start after our last confirmed point
                    hypothesisWords = result.allWords.filter { $0.start >= lastAgreedSeconds }
                    
                    if let prevResult = prevResult {
                        prevWords = prevResult.allWords.filter { $0.start >= lastAgreedSeconds }
                        let commonPrefix = findLongestCommonPrefix(prevWords, hypothesisWords)
                        
                        // If we have enough matching words, confirm them
                        if commonPrefix.count >= tokenConfirmationsNeeded {
                            lastAgreedWords = Array(commonPrefix.suffix(tokenConfirmationsNeeded))
                            lastAgreedSeconds = lastAgreedWords.first?.start ?? lastAgreedSeconds
                            
                            // Add confirmed words except for the confirmation window
                            let newConfirmedWords = commonPrefix.prefix(commonPrefix.count - tokenConfirmationsNeeded)
                            confirmedWords.append(contentsOf: newConfirmedWords)
                            
                            // Update confirmed text
                            confirmedText = confirmedWords.map { $0.word }.joined(separator: " ")
                        }
                    }
                    
                    // Update hypothesis text with current hypothesis
                    let currentHypothesis = lastAgreedWords + hypothesisWords
                    hypothesisText = currentHypothesis.map { $0.word }.joined(separator: " ")
                    
                    // Store result for next comparison
                    prevResult = result
                    eagerResults.append(result)
                    
                    // Update the published transcribed text
                    transcribedText = confirmedText + (hypothesisText.isEmpty ? "" : " " + hypothesisText)
                }
            }
            
        } catch {
            print("Error transcribing audio: \(error)")
        }
    }
    
    private func calculateBufferEnergy(_ samples: [Float]) -> Float {
        let sum = samples.reduce(0) { $0 + abs($1) }
        return sum / Float(samples.count)
    }
    
    private func compressionRatio(of tokens: [Int]) -> Float {
        let tokenString = tokens.map { String($0) }.joined(separator: ",")
        let data = tokenString.data(using: .utf8) ?? Data()
        
        guard let compressed = try? (data as NSData).compressed(using: .zlib),
              compressed.length > 0 else {
            return 1.0
        }
        
        return Float(compressed.length) / Float(data.count)
    }
    
    private func findLongestCommonPrefix(_ a: [WordTiming], _ b: [WordTiming]) -> [WordTiming] {
        var prefix: [WordTiming] = []
        for (wordA, wordB) in zip(a, b) {
            if wordA.word == wordB.word && abs(wordA.start - wordB.start) < 0.5 {
                prefix.append(wordA)
            } else {
                break
            }
        }
        return prefix
    }
    
    private func resetTranscriptionState() {
        currentText = ""
        confirmedText = ""
        hypothesisText = ""
        lastBufferSize = 0
        currentFallbacks = 0
        lastAgreedSeconds = 0.0
        prevResult = nil
        prevWords = []
        lastAgreedWords = []
        confirmedWords = []
        hypothesisWords = []
        eagerResults = []
        transcribedText = ""
    }
}

@available(macOS 15.0, *)
class ScreenCaptureStreamOutput: NSObject, SCStreamOutput {
    typealias AudioSampleHandler = (AVAudioPCMBuffer) -> Void
    typealias MicrophoneHandler = (AVAudioPCMBuffer) -> Void
    
    private var audioSampleHandler: AudioSampleHandler?
    private var microphoneHandler: MicrophoneHandler?
    
    init(audioSampleHandler: AudioSampleHandler? = nil,
         microphoneHandler: MicrophoneHandler? = nil) {
        self.audioSampleHandler = audioSampleHandler
        self.microphoneHandler = microphoneHandler
        super.init()
    }
    
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
