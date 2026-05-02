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

    var body: some View {
        VStack(spacing: 20) {
            Button("Get Emoji") {
                Task {
                    await fetchEmojis()
                }
            }

            if isLoading {
                ProgressView()
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }

            List(emojis) { emoji in
                HStack {
                    Text(emoji.name ?? "")

                    Spacer()

                    AsyncImage(url: URL(string: emoji.url ?? "")) { image in
                        image
                            .resizable()
                            .scaledToFit()
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 32, height: 32)
                }
            }
        }
        .padding()
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
        let request: NSFetchRequest<EmojiItem> = EmojiItem.fetchRequest()
        let storedEmojis = try viewContext.fetch(request)
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
}
