//
//  ModelDownload.swift
//  GranolaClone
//
//  Created by Partha Praharaj on 16/01/25.
//

import SwiftUI
import WhisperKit

struct ModelDownload: View {
    var manager: WhisperManager
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Loading WhisperKit Model...")
                .font(.headline)
            
            ProgressView(value: manager.downloadProgress)
                .progressViewStyle(.linear)
                .frame(maxWidth: 300)
            
            Text(manager.modelState.description)
                .foregroundColor(.secondary)
        }
    }
}
