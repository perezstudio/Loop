//
//  LoopApp.swift
//  Loop
//
//  Created by Kevin Perez on 6/17/25.
//

import SwiftUI

@main
struct LoopApp: App {
    var body: some Scene {
        WindowGroup {
            MainAppView()
        }
        .defaultSize(width: 1200, height: 800)
    }
}

struct MainAppView: View {
    @State private var selectedTab = "browser"
    
    var body: some View {
        TabView(selection: $selectedTab) {
            WebBrowserView()
                .tabItem {
                    Image(systemName: "globe")
                    Text("Browser")
                }
                .tag("browser")
            
            ContentView()
                .tabItem {
                    Image(systemName: "wrench.and.screwdriver")
                    Text("Engine Tests")
                }
                .tag("tests")
        }
        .frame(minWidth: 1000, minHeight: 700)
    }
}
