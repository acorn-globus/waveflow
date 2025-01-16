import Foundation
import WhisperKit
import ScreenCaptureKit
import AVFAudio
import Accelerate

class SystemAudioProcessor: ObservableObject {
    // Use ContiguousArray for better performance with audio processing
    private var audioSampleBuffer: ContiguousArray<Float> = []
    private var stream: SCStream?
    private var streamOutput: StreamOutput?
    
    // Add energy tracking similar to microphone implementation
    private var audioEnergy: [(rel: Float, avg: Float, max: Float, min: Float)] = []
    private var relativeEnergyWindow: Int = 20
    
    var audioSamples: ContiguousArray<Float> {
        return audioSampleBuffer
    }
    
    init() {
        Task {
            do {
                try await setupSystemAudio()
            } catch {
                print("Failed to setup system audio: \(error)")
            }
        }
    }
    
    func setupSystemAudio() async throws {
        // Get shareable content
        let content = try await SCShareableContent.current
        
        // Configure audio only stream
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        
        // Create stream output with proper sample rate
        streamOutput = StreamOutput()
        streamOutput?.audioBufferHandler = { [weak self] pcmBuffer in
            guard let self = self else { return }
            
            // Convert and validate the audio buffer
            if let samples = self.processAudioBuffer(pcmBuffer) {
                self.audioSampleBuffer.append(contentsOf: samples)
                
                // Calculate and store energy values
                let energy = self.calculateEnergy(of: samples)
                let relativeEnergy = self.calculateRelativeEnergy(energy)
                self.audioEnergy.append((relativeEnergy, energy.avg, energy.max, energy.min))
            }
        }
        
        // Set up stream with first available display
        if let display = content.displays.first {
            let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            stream = SCStream(filter: filter, configuration: config, delegate: streamOutput! as? SCStreamDelegate)
            try stream?.addStreamOutput(streamOutput!, type: .audio, sampleHandlerQueue: .global())
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) -> [Float]? {
        // Ensure we're working with the correct format (16kHz, mono)
        if buffer.format.sampleRate != Double(WhisperKit.sampleRate) {
            // Create converter if needed
            let outputFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: Double(WhisperKit.sampleRate),
                channels: 1,
                interleaved: false
            )!
            
            if let converter = AVAudioConverter(from: buffer.format, to: outputFormat),
               let convertedBuffer = try? resampleBuffer(buffer, with: converter) {
                return convertBufferToArray(convertedBuffer)
            }
        }
        
        return convertBufferToArray(buffer)
    }
    
    private func resampleBuffer(_ buffer: AVAudioPCMBuffer, with converter: AVAudioConverter) throws -> AVAudioPCMBuffer {
        let capacity = converter.outputFormat.sampleRate * Double(buffer.frameLength) / converter.inputFormat.sampleRate
        let frameCapacity = AVAudioFrameCount(capacity.rounded(.up))
        
        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: converter.outputFormat,
            frameCapacity: frameCapacity
        ) else {
            throw NSError(domain: "AudioProcessing", code: -1)
        }
        
        var error: NSError?
        converter.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        return convertedBuffer
    }
    
    private func convertBufferToArray(_ buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData else { return [] }
        
        let frameLength = Int(buffer.frameLength)
        var result = [Float](repeating: 0, count: frameLength)
        
        // Use vDSP for efficient memory copy
        vDSP_mmov(
            channelData[0],
            &result,
            vDSP_Length(frameLength),
            1,
            vDSP_Length(frameLength),
            1
        )
        
        return result
    }
    
    private func calculateEnergy(of signal: [Float]) -> (avg: Float, max: Float, min: Float) {
        var rmsEnergy: Float = 0.0
        var maxEnergy: Float = 0.0
        var minEnergy: Float = 0.0
        
        vDSP_rmsqv(signal, 1, &rmsEnergy, vDSP_Length(signal.count))
        vDSP_maxmgv(signal, 1, &maxEnergy, vDSP_Length(signal.count))
        vDSP_minmgv(signal, 1, &minEnergy, vDSP_Length(signal.count))
        
        return (rmsEnergy, maxEnergy, minEnergy)
    }
    
    private func calculateRelativeEnergy(_ energy: (avg: Float, max: Float, min: Float)) -> Float {
        // Get the lowest average energy from recent buffers
        let minAvgEnergy = audioEnergy.suffix(relativeEnergyWindow)
            .map { $0.avg }
            .min() ?? 1e-3
        
        // Convert to dB and normalize
        let dbEnergy = 20 * log10(energy.avg)
        let refEnergy = 20 * log10(max(1e-8, minAvgEnergy))
        let normalizedEnergy = (dbEnergy - refEnergy) / (-refEnergy)
        
        return max(0, min(normalizedEnergy, 1))
    }
    
    func startRecording() async throws {
        // Clear previous state
        audioSampleBuffer.removeAll()
        audioEnergy.removeAll()
        
        print("Starting system audio recording...")
        try await stream?.startCapture()
    }
    
    func stopRecording() {
        Task {
            try? await stream?.stopCapture()
            stream = nil
            audioSampleBuffer.removeAll()
            audioEnergy.removeAll()
        }
    }
}

// Improved StreamOutput implementation
private class StreamOutput: NSObject, SCStreamOutput {
    var audioBufferHandler: ((AVAudioPCMBuffer) -> Void)?
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio,
              let pcmBuffer = createAudioBuffer(from: sampleBuffer) else {
            return
        }
        
        audioBufferHandler?(pcmBuffer)
    }
    
    private func createAudioBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              var asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee,
              let audioFormat = AVAudioFormat(streamDescription: &asbd) else {
            return nil
        }
        
        let frameCount = CMSampleBufferGetNumSamples(sampleBuffer)
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(frameCount)),
              let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return nil
        }
        
        pcmBuffer.frameLength = AVAudioFrameCount(frameCount)
        
        var blockBufferLength = 0
        var blockBufferDataPointer: UnsafeMutablePointer<Int8>?
        
        let status = CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: &blockBufferLength,
            totalLengthOut: nil,
            dataPointerOut: &blockBufferDataPointer
        )
        
        guard status == kCMBlockBufferNoErr,
              let dataPointer = blockBufferDataPointer,
              let channelData = pcmBuffer.floatChannelData else {
            return nil
        }
        
        // Copy data efficiently using memcpy
        memcpy(channelData[0], dataPointer, blockBufferLength)
        
        return pcmBuffer
    }
}
