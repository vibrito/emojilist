//
//  ContentView.swift
//  Emoji List
//
//  Created by MLBBR-MAC-VINICIUS on 02/05/26.
//

import SwiftUI
import CoreData
import UIKit

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \EmojiItem.name, ascending: true)],
        animation: .default)
    private var emojis: FetchedResults<EmojiItem>

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedEmojiID: NSManagedObjectID?
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

                if let selectedEmojiID, let selectedEmojiName, let selectedEmojiURL {
                    VStack(spacing: 12) {
                        CachedEmojiImage(
                            emojiID: selectedEmojiID,
                            url: selectedEmojiURL,
                            size: 96
                        )

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

            selectedEmojiID = emoji.objectID
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
            if emoji.url != url {
                emoji.imageData = nil
            }

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

    @State private var displayedEmojis: [EmojiGridItem] = []

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(displayedEmojis) { emoji in
                    Button {
                        remove(emoji)
                    } label: {
                        VStack(spacing: 8) {
                            CachedEmojiImage(
                                emojiID: emoji.id,
                                url: emoji.url,
                                size: 48
                            )

                            Text(emoji.name)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 96)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("Emoji List")
        .onAppear(perform: resetDisplayedEmojis)
        .refreshable {
            resetDisplayedEmojis()
        }
    }

    private func remove(_ emoji: EmojiGridItem) {
        displayedEmojis.removeAll { $0.id == emoji.id }
    }

    private func resetDisplayedEmojis() {
        displayedEmojis = emojis.map { emoji in
            EmojiGridItem(
                id: emoji.objectID,
                name: emoji.name ?? "",
                url: emoji.url ?? ""
            )
        }
    }
}

struct EmojiGridItem: Identifiable {
    let id: NSManagedObjectID
    let name: String
    let url: String
}

struct CachedEmojiImage: View {
    @Environment(\.managedObjectContext) private var viewContext

    let emojiID: NSManagedObjectID
    let url: String
    let size: CGFloat

    @State private var image: UIImage?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
            }
        }
        .frame(width: size, height: size)
        .task(id: emojiID) {
            await loadImage()
        }
    }

    @MainActor
    private func loadImage() async {
        image = nil

        if let cachedImage = cachedImage() {
            image = cachedImage
            return
        }

        guard !isLoading, let imageURL = URL(string: url) else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: imageURL)

            guard let downloadedImage = UIImage(data: data),
                  let emoji = try viewContext.existingObject(with: emojiID) as? EmojiItem
            else { return }

            emoji.imageData = data
            try viewContext.save()
            image = downloadedImage
        } catch {
            image = nil
        }
    }

    private func cachedImage() -> UIImage? {
        guard let emoji = try? viewContext.existingObject(with: emojiID) as? EmojiItem,
              let imageData = emoji.imageData
        else { return nil }

        return UIImage(data: imageData)
    }
}
