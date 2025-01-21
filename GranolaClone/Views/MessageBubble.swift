//
//  MessageBubble.swift
//  GranolaClone
//
//  Created by Partha Praharaj on 20/01/25.
//

import SwiftUI

struct MessageBubble: View {
    let message: TranscriptionMessage
    let hypothesisText: String
    
    var body: some View {
        HStack {
            if message.source == "microphone" {
                Spacer()
            }
            
            VStack(alignment: message.source == "microphone" ? .trailing : .leading) {
                HStack(alignment: .top, spacing: 0) {
                    Text("\(Text(message.text).fontWeight(.bold)) \(Text(hypothesisText).fontWeight(.light))")
                }
                .padding()
                .background(message.source == "microphone" ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                .cornerRadius(12)
                
                Text(message.createdAt.formatted(date: .omitted, time: .shortened))
            }
            .frame(alignment: message.source == "microphone" ? .trailing : .leading)
            
            if message.source == "system" {
                Spacer()
            }
        }
    }
}
