//
//  PermissionSection.swift
//  GranolaClone
//
//  Created by Partha Praharaj on 07/01/25.
//

import SwiftUI

struct PermissionSection: View {
    let title: String
    let granted: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(title)
                Spacer()
                if !granted {
                    Button("Request Permission") {
                        action()
                    }
                    .buttonStyle(.borderedProminent)
                }else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    PermissionSection(
        title: "Some Access",
        granted: false,
        action: {}
    )}
