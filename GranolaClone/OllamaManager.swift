import Foundation
import OllamaKit
import SwiftUI

enum OllamaError: Error {
    case notInstalled
    case serverStartFailed
    case modelDownloadFailed
    case modelNotFound
    case generateResponseFailed
}

@MainActor
class OllamaManager: ObservableObject {
    private let defaultModel = "llama3.2"
    private var ollamaKit: OllamaKit?
    private let baseUrl = URL(string: "http://localhost:11434")
    private var serverProcess: Process = Process()
    
    @Published var isServerRunning = false
    @Published var isModelLoaded: Bool = false
    @Published var downloadProgress: Float = 0.0
    @Published var isDownloading = false
    @Published var installationSteps: [String] = []
    @Published var summaryData = ""
    
    init() {
        setupOllama()
        startOllamaServer()
    }
    
    private func setupOllama() {
        guard let ollamaPath = Bundle.main.path(forResource: "ollama", ofType: nil, inDirectory: "ollama") else {
            print("Error: Ollama binary not found")
            return
        }
        
        // Set executable permissions
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: ollamaPath)
    }
    
    private func startOllamaServer() {
        guard let ollamaPath = Bundle.main.path(forResource: "ollama", ofType: nil, inDirectory: "ollama") else {
            print("Error: Ollama binary not found")
            return
        }
        print(ollamaPath)
        
        serverProcess.launchPath = ollamaPath
        serverProcess.arguments = ["serve"]
        
        do {
            try serverProcess.run()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.initializeOllamaKit()
            }
        } catch {
            print("Failed to start Ollama server: \(error)")
        }
    }
    
    private func initializeOllamaKit() {
        ollamaKit = OllamaKit(baseURL: baseUrl!)
        guard let ollamaKit else { return }
        Task {
            isServerRunning = await ollamaKit.reachable()
            guard isServerRunning else { return }
            
            let isModelAvailable = try await isModelAvailable(modelName: defaultModel)
            if !isModelAvailable {
                try await downloadModel(modelName: defaultModel)
            } else {
                isModelLoaded = true
            }
        }
    }
    
    func isModelAvailable(modelName: String = "") async throws -> Bool {
        guard let ollamaKit = ollamaKit else {
            throw OllamaError.serverStartFailed
        }
        
        do {
            let data = try await ollamaKit.models()
            
            return data.models.contains(where: { $0.name == modelName })
        } catch {
            throw OllamaError.modelNotFound
        }
    }
    
    func downloadModel(modelName: String) async throws {
        guard let ollamaKit = ollamaKit else {
            throw OllamaError.serverStartFailed
        }
        
        isDownloading = true
        downloadProgress = 0.0
        
        do {
            let reqData = OKPullModelRequestData(model: modelName)

            for try await response in ollamaKit.pullModel(data: reqData) {
              if let progress = response.completed, let total = response.total {
                print("Progress: \(progress)/\(total) bytes")
                downloadProgress = (Float(progress) / Float(total))
              }
            }
            isDownloading = false
            isModelLoaded = true
        } catch {
            isDownloading = false
            throw OllamaError.modelDownloadFailed
        }
    }
    
    func generateResponse(prompt: String) async throws{
        guard let ollamaKit = ollamaKit else {
            throw OllamaError.serverStartFailed
        }

        summaryData = ""
        let reqData = OKGenerateRequestData(model: defaultModel, prompt: prompt)
        
        Task {
            do {
                for try await responseData in ollamaKit.generate(data: reqData) {
                    // Handle each generated response
                    print("Response: \(responseData)")
                    print("Response Text: \(responseData.response)")
                    summaryData = responseData.response
                }
            } catch {
                // Handle error
                throw OllamaError.generateResponseFailed
            }
        }
       
    }
    
    func shutdown() {
        // Implement cleanup logic if needed
        isServerRunning = false
        ollamaKit = nil
        serverProcess.terminate()
    }
}
