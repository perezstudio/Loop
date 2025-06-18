//
//  ContentView.swift
//  Loop
//
//  Created by Kevin Perez on 6/17/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
	@Environment(\.modelContext) private var modelContext
	@Query private var items: [Item]

	var body: some View {
		WebRenderer(urlString: "https://google.com")
	}

}

#Preview {
	ContentView()
		.modelContainer(for: Item.self, inMemory: true)
}
