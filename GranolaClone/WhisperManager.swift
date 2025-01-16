import Foundation
import WhisperKit
import Combine
import AVFoundation

@MainActor
class WhisperManager: ObservableObject {
    @Published var isModelLoaded = false
    @Published var isRecording = false
    @Published var confirmedText = ""
    @Published var hypothesisText = ""
    @Published var downloadProgress: Float = 0.0
    @Published var modelState: ModelState = .unloaded
    
    private var whisperKit: WhisperKit?
    private var transcriptionTask: Task<Void, Never>?
    private var lastBufferSize = 0
    private var lastAgreedSeconds: Float = 0.0
    private var prevResult: TranscriptionResult?
    private var prevWords: [WordTiming] = []
    private var lastAgreedWords: [WordTiming] = []
    private var confirmedWords: [WordTiming] = []
    private var hypothesisWords: [WordTiming] = []
    private let tokenConfirmationsNeeded: Int = 2
    
    private let modelName = "whisper-large-v3"
    private let repoName = "argmaxinc/whisperkit-coreml"
    
    init() {
        Task {
            await loadModel()
        }
    }
    
    private func loadModel() async {
        do {
            whisperKit = try await WhisperKit(
                verbose: true,
                logLevel: .debug,
                prewarm: false,
                load: false,
                download: false
            )
            
            guard let whisperKit = whisperKit else { return }
            
            // Download model if needed
            let folder = try await WhisperKit.download(
                variant: modelName,
                from: repoName,
                progressCallback: { progress in
                    Task { @MainActor in
                        self.downloadProgress = Float(progress.fractionCompleted)
                        self.modelState = .downloading
                    }
                }
            )
            
            modelState = .downloaded
            whisperKit.modelFolder = folder
            
            // Prewarm and load models
            try await whisperKit.prewarmModels()
            try await whisperKit.loadModels()
            
            modelState = .loaded
            isModelLoaded = true
        } catch {
            print("Error loading model: \(error)")
            modelState = .unloaded
        }
    }
    
    func toggleRecording() {
        isRecording.toggle()
        
        if isRecording {
            startRecording()
        } else {
            stopRecording()
        }
    }
    
    private func startRecording() {
        resetState()
        guard let audioProcessor = whisperKit?.audioProcessor else { return }
        
        Task(priority: .userInitiated) {
            guard await AudioProcessor.requestRecordPermission() else {
                print("Microphone access denied")
                return
            }
            
            try? audioProcessor.startRecordingLive { _ in }
            transcriptionTask = Task { [weak self] in
                while self?.isRecording == true {
                    try? await self?.transcribeCurrentBuffer()
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
                }
            }
        }
    }
    
    private func resetState() {
        lastBufferSize = 0
        lastAgreedSeconds = 0.0
        prevResult = nil
        prevWords = []
        lastAgreedWords = []
        confirmedWords = []
        hypothesisWords = []
        confirmedText = ""
        hypothesisText = ""
    }
    
    private func stopRecording() {
        whisperKit?.audioProcessor.stopRecording()
        transcriptionTask?.cancel()
        transcriptionTask = nil
    }
    
    private func findLongestCommonPrefix(_ a: [WordTiming], _ b: [WordTiming]) -> [WordTiming] {
        var commonPrefix: [WordTiming] = []
        let minLength = min(a.count, b.count)
        
        for i in 0..<minLength {
            if a[i].word == b[i].word && abs(a[i].start - b[i].start) < 0.5 {
                commonPrefix.append(a[i])
            } else {
                break
            }
        }
        
        return commonPrefix
    }
    
    private func findLongestDifferentSuffix(_ a: [WordTiming], _ b: [WordTiming]) -> [WordTiming] {
        let commonPrefix = findLongestCommonPrefix(a, b)
        return Array(b.dropFirst(commonPrefix.count))
    }

    private func transcribeCurrentBuffer() async throws {
        guard let whisperKit = whisperKit else { return }
        
        let currentBuffer = whisperKit.audioProcessor.audioSamples
        let nextBufferSize = currentBuffer.count - lastBufferSize
        let nextBufferSeconds = Float(nextBufferSize) / Float(WhisperKit.sampleRate)
        
        // Only transcribe if we have at least 1 second of new audio
        guard nextBufferSeconds > 1 else { return }
        
        lastBufferSize = currentBuffer.count
        
        print("Transcribing \(lastAgreedSeconds)-\(Double(currentBuffer.count)/16000.0) seconds")
        
        let options = DecodingOptions(
            verbose: false,
            task: .transcribe,
            language: "en",
            temperature: 0,
            sampleLength: 224,
            usePrefillPrompt: true,
            skipSpecialTokens: true,
            withoutTimestamps: true,
            wordTimestamps: true,
            clipTimestamps: [lastAgreedSeconds]
        )
        
        if let transcription: TranscriptionResult = try await whisperKit.transcribe(
            audioArray: Array(currentBuffer),
            decodeOptions: options
        ) {
            await MainActor.run {
                hypothesisWords = transcription.allWords.filter { $0.start >= lastAgreedSeconds }
                
                if let prevResult = prevResult {
                    prevWords = prevResult.allWords.filter { $0.start >= lastAgreedSeconds }
                    let commonPrefix = findLongestCommonPrefix(prevWords, hypothesisWords)
                    
                    print("Prev: \((prevWords.map { $0.word }).joined())")
                    print("Next: \((hypothesisWords.map { $0.word }).joined())")
                    print("Common prefix: \((commonPrefix.map { $0.word }).joined())")
                    
                    if commonPrefix.count >= tokenConfirmationsNeeded {
                        lastAgreedWords = Array(commonPrefix.suffix(tokenConfirmationsNeeded))
                        lastAgreedSeconds = lastAgreedWords.first?.start ?? lastAgreedSeconds
                        print("New last agreed word '\(lastAgreedWords.first?.word ?? "")' at \(lastAgreedSeconds) seconds")
                        
                        confirmedWords.append(contentsOf: commonPrefix.prefix(commonPrefix.count - tokenConfirmationsNeeded))
                    } else {
                        print("Using same last agreed time \(lastAgreedSeconds)")
                    }
                }
                
                prevResult = transcription
                
                // Update the displayed text
                confirmedText = confirmedWords.map { $0.word }.joined()
                
                // Get the latest hypothesis by combining last agreed words with the different suffix
                let lastHypothesis = lastAgreedWords + findLongestDifferentSuffix(prevWords, hypothesisWords)
                hypothesisText = lastHypothesis.map { $0.word }.joined()
            }
        }
    }
}
