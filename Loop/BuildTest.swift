//
//  BuildTest.swift
//  Loop
//
//  Created by Kevin Perez on 6/17/25.
//

import SwiftUI

// MARK: - Minimal Build Test

struct BuildTest: View {
    var body: some View {
        VStack {
            Text("Build Test - Minimal")
                .font(.title)
            
            Text("This is a minimal test to verify compilation")
                .padding()
        }
        .padding()
    }
}

#Preview {
    BuildTest()
}
