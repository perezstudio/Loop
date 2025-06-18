//
//  ContentView.swift
//  Loop
//
//  Created by Kevin Perez on 6/17/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        BrowserEngineView()
            .frame(minWidth: 1000, minHeight: 700)
            .onAppear {
                print("🚀 Loop Browser started with WebCore Engine")
                print("🌐 Features enabled:")
                print("   • WebKit-inspired architecture")
                print("   • HTML5 parsing with CSS3 styling")
                print("   • Modern layout engine (Block + Flexbox)")
                print("   • CoreGraphics rendering pipeline")
                print("   • URL fetching with network monitoring")
                print("   • Developer tools and performance metrics")
            }
    }
}

#Preview {
    ContentView()
        .frame(width: 1200, height: 800)
}
