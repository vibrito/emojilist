//
//  ContentView.swift
//  Emoji List
//
//  Created by MLBBR-MAC-VINICIUS on 02/05/26.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \EmojiItem.name, ascending: true)],
        animation: .default)
    private var emojis: FetchedResults<EmojiItem>

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedEmojiName: String?
    @State private var selectedEmojiURL: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Button("Random Emoji") {
                    Task {
                        await showRandomEmoji()
                    }
                }

                NavigationLink("Emoji List") {
                    EmojiGridView()
                }

                if isLoading {
                    ProgressView()
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }

                if let selectedEmojiName, let selectedEmojiURL {
                    VStack(spacing: 12) {
                        AsyncImage(url: URL(string: selectedEmojiURL)) { image in
                            image
                                .resizable()
                                .scaledToFit()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 96, height: 96)

                        Text(selectedEmojiName)
                            .font(.headline)
                    }
                }
            }
            .padding()
            .navigationTitle("Emoji")
        }
    }

    @MainActor
    func showRandomEmoji() async {
        await fetchEmojis()

        do {
            let cachedEmojis = try fetchCachedEmojis()

            guard let emoji = cachedEmojis.randomElement() else {
                errorMessage = "No emojis available"
                return
            }

            selectedEmojiName = emoji.name
            selectedEmojiURL = emoji.url
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func fetchEmojis() async {
        guard emojis.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        guard let url = URL(string: "https://api.github.com/emojis") else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            let response = try JSONDecoder().decode(EmojiResponse.self, from: data)

            try save(response)

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func save(_ response: EmojiResponse) throws {
        let storedEmojis = try fetchCachedEmojis()
        var storedEmojisByName: [String: EmojiItem] = [:]

        for emoji in storedEmojis {
            guard let name = emoji.name else { continue }

            if storedEmojisByName[name] == nil {
                storedEmojisByName[name] = emoji
            } else {
                viewContext.delete(emoji)
            }
        }

        for (name, url) in response {
            let emoji = storedEmojisByName[name] ?? EmojiItem(context: viewContext)
            emoji.name = name
            emoji.url = url
        }

        let responseNames = Set(response.keys)
        for emoji in storedEmojis where emoji.name.map({ !responseNames.contains($0) }) ?? false {
            viewContext.delete(emoji)
        }

        if viewContext.hasChanges {
            try viewContext.save()
        }
    }

    private func fetchCachedEmojis() throws -> [EmojiItem] {
        let request: NSFetchRequest<EmojiItem> = EmojiItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \EmojiItem.name, ascending: true)]

        return try viewContext.fetch(request)
    }
}

struct EmojiGridView: View {
    private let columns = [
        GridItem(.adaptive(minimum: 96), spacing: 16)
    ]

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \EmojiItem.name, ascending: true)],
        animation: .default)
    private var emojis: FetchedResults<EmojiItem>

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(emojis) { emoji in
                    VStack(spacing: 8) {
                        AsyncImage(url: URL(string: emoji.url ?? "")) { image in
                            image
                                .resizable()
                                .scaledToFit()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 48, height: 48)

                        Text(emoji.name ?? "")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 96)
                }
            }
            .padding()
        }
        .navigationTitle("Emoji List")
    }
}
