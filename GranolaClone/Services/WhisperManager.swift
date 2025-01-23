import Foundation
import WhisperKit
import Combine
import AVFoundation
import ScreenCaptureKit

@MainActor
class WhisperManager: ObservableObject {
    @Published var isModelLoaded = false
    @Published var isRecording = false
    @Published var downloadProgress: Float = 0.0
    @Published var modelState: ModelState = .unloaded

    // Microphone transcription
    @Published var micConfirmedTextReset = ""
    @Published var micConfirmedText = ""
    @Published var micHypothesisText = ""

    // System audio transcription
    @Published var systemConfirmedTextReset = ""
    @Published var systemConfirmedText = ""
    @Published var systemHypothesisText = ""

    private var whisperKit: WhisperKit?
    private var micTranscriptionTask: Task<Void, Never>?
    private var systemTranscriptionTask: Task<Void, Never>?

    // Screen capture properties
    private var streamConfig: SCStreamConfiguration?
    private var stream: SCStream?
    private var systemAudioProcessor: SystemAudioProcessor?

    // Microphone state
    private var micLastBufferSize = 0
    private var micLastAgreedSeconds: Float = 0.0
    private var micPrevResult: TranscriptionResult?
    private var micPrevWords: [WordTiming] = []
    private var micLastAgreedWords: [WordTiming] = []
    private var micConfirmedWords: [WordTiming] = []
    private var micHypothesisWords: [WordTiming] = []

    // System audio state
    private var systemLastBufferSize = 0
    private var systemLastAgreedSeconds: Float = 0.0
    private var systemPrevResult: TranscriptionResult?
    private var systemPrevWords: [WordTiming] = []
    private var systemLastAgreedWords: [WordTiming] = []
    private var systemConfirmedWords: [WordTiming] = []
    private var systemHypothesisWords: [WordTiming] = []

    private let tokenConfirmationsNeeded: Int = 2
    private let modelName = "whisper-small"
    private let repoName = "argmaxinc/whisperkit-coreml"

    init() {
        Task {
            await loadModel()
            setupSystemAudioProcessor()
        }
    }

    private func setupSystemAudioProcessor() {
        systemAudioProcessor = SystemAudioProcessor()
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

    private func resetState() {
        resetMicrophoneState()
        resetSystemAudioState()
    }

    private func resetMicrophoneState() {
        micLastBufferSize = 0
        micLastAgreedSeconds = 0.0
        micPrevResult = nil
        micPrevWords = []
        micLastAgreedWords = []
        micConfirmedWords = []
        micHypothesisWords = []
        micConfirmedText = ""
        micHypothesisText = ""
    }

    private func resetSystemAudioState() {
        systemLastBufferSize = 0
        systemLastAgreedSeconds = 0.0
        systemPrevResult = nil
        systemPrevWords = []
        systemLastAgreedWords = []
        systemConfirmedWords = []
        systemHypothesisWords = []
        systemConfirmedText = ""
        systemHypothesisText = ""
    }

    private func startRecording() {
        resetState()

        // Start microphone recording
        startMicrophoneRecording()

        // Start system audio recording
        startSystemAudioRecording()
    }

    private func startMicrophoneRecording() {
        guard let audioProcessor = whisperKit?.audioProcessor else { return }

        Task(priority: .userInitiated) {
            guard await AudioProcessor.requestRecordPermission() else {
                print("Microphone access denied")
                return
            }

            try? audioProcessor.startRecordingLive { _ in }
            micTranscriptionTask = Task { [weak self] in
                while self?.isRecording == true {
                    try? await self?.transcribeMicrophoneBuffer()
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
                }
            }
        }
    }

    private func startSystemAudioRecording() {
        Task {
            do {
                try await systemAudioProcessor?.startRecording()
                systemTranscriptionTask = Task { [weak self] in
                    while self?.isRecording == true {
                        try? await self?.transcribeSystemBuffer()
                        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
                    }
                }
            } catch {
                print("Error starting system audio recording: \(error)")
            }
        }
    }

    private func stopRecording() {
        // Stop microphone recording
        whisperKit?.audioProcessor.stopRecording()
        micTranscriptionTask?.cancel()
        micTranscriptionTask = nil

        // Stop system audio recording
        systemAudioProcessor?.stopRecording()
        systemTranscriptionTask?.cancel()
        systemTranscriptionTask = nil

        finalizeText()
    }

    func finalizeText() {
        // Finalize unconfirmed text
        Task {
            await MainActor.run {
                if micHypothesisText != "" {
                    micConfirmedText += micHypothesisText
                    micConfirmedTextReset = micHypothesisText
                    micHypothesisText = ""
                }
                if systemHypothesisText != "" {
                    systemConfirmedText += systemHypothesisText
                    systemConfirmedTextReset = systemHypothesisText
                    systemHypothesisText = ""
                }
            }
        }
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

    private func transcribeMicrophoneBuffer() async throws {
        guard let whisperKit = whisperKit else { return }

        let currentBuffer = whisperKit.audioProcessor.audioSamples
        let nextBufferSize = currentBuffer.count - micLastBufferSize
        let nextBufferSeconds = Float(nextBufferSize) / Float(WhisperKit.sampleRate)

        guard nextBufferSeconds > 1 else { return }

        micLastBufferSize = currentBuffer.count

        print("Transcribing mic \(micLastAgreedSeconds)-\(Double(currentBuffer.count)/16000.0) seconds")

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
            clipTimestamps: [micLastAgreedSeconds]
        )

        if let transcription: TranscriptionResult = try await whisperKit.transcribe(
            audioArray: Array(currentBuffer),
            decodeOptions: options
        ) {
            await MainActor.run {
                micHypothesisWords = transcription.allWords.filter { $0.start >= micLastAgreedSeconds }

                if let prevResult = micPrevResult {
                    micPrevWords = prevResult.allWords.filter { $0.start >= micLastAgreedSeconds }
                    let commonPrefix = findLongestCommonPrefix(micPrevWords, micHypothesisWords)

                    if commonPrefix.count >= tokenConfirmationsNeeded {
                        micLastAgreedWords = Array(commonPrefix.suffix(tokenConfirmationsNeeded))
                        micLastAgreedSeconds = micLastAgreedWords.first?.start ?? micLastAgreedSeconds
                        micConfirmedWords.append(contentsOf: commonPrefix.prefix(commonPrefix.count - tokenConfirmationsNeeded))
                        micConfirmedTextReset = commonPrefix.prefix(commonPrefix.count - tokenConfirmationsNeeded).map { $0.word }.joined()
                    }
                }

                micPrevResult = transcription

                // Update the displayed text
                micConfirmedText = micConfirmedWords.map { $0.word }.joined()

                // Get the latest hypothesis
                let lastHypothesis = micLastAgreedWords + findLongestDifferentSuffix(micPrevWords, micHypothesisWords)
                micHypothesisText = lastHypothesis.map { $0.word }.joined()
            }
        }
    }

    private func transcribeSystemBuffer() async throws {
        guard let whisperKit = whisperKit,
              let systemBuffer = systemAudioProcessor?.audioSamples else { return }

        let nextBufferSize = systemBuffer.count - systemLastBufferSize
        let nextBufferSeconds = Float(nextBufferSize) / Float(WhisperKit.sampleRate)

        guard nextBufferSeconds > 1 else { return }

        systemLastBufferSize = systemBuffer.count

        print("Transcribing system \(systemLastAgreedSeconds)-\(Double(systemBuffer.count)/16000.0) seconds")

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
            clipTimestamps: [systemLastAgreedSeconds]
        )

        if let transcription: TranscriptionResult = try await whisperKit.transcribe(
            audioArray: Array(systemBuffer),
            decodeOptions: options
        ) {
            await MainActor.run {
                systemHypothesisWords = transcription.allWords.filter { $0.start >= systemLastAgreedSeconds }

                if let prevResult = systemPrevResult {
                    systemPrevWords = prevResult.allWords.filter { $0.start >= systemLastAgreedSeconds }
                    let commonPrefix = findLongestCommonPrefix(systemPrevWords, systemHypothesisWords)

                    if commonPrefix.count >= tokenConfirmationsNeeded {
                        systemLastAgreedWords = Array(commonPrefix.suffix(tokenConfirmationsNeeded))
                        systemLastAgreedSeconds = systemLastAgreedWords.first?.start ?? systemLastAgreedSeconds
                        systemConfirmedWords.append(contentsOf: commonPrefix.prefix(commonPrefix.count - tokenConfirmationsNeeded))
                        systemConfirmedTextReset = commonPrefix.prefix(commonPrefix.count - tokenConfirmationsNeeded).map { $0.word }.joined()
                    }
                }

                systemPrevResult = transcription

                // Update the displayed text
                systemConfirmedText = systemConfirmedWords.map { $0.word }.joined()

                // Get the latest hypothesis
                let lastHypothesis = systemLastAgreedWords + findLongestDifferentSuffix(systemPrevWords, systemHypothesisWords)
                systemHypothesisText = lastHypothesis.map { $0.word }.joined()
            }
        }
    }
}
