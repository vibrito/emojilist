//
//  ContentView.swift
//  Emoji List
//
//  Created by MLBBR-MAC-VINICIUS on 02/05/26.
//

import SwiftUI

struct ContentView: View {
    @State private var emojis: [Emoji] = []
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
                    Text(emoji.name)

                    Spacer()

                    AsyncImage(url: URL(string: emoji.url)) { image in
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

    func fetchEmojis() async {
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

            emojis = response.map { key, value in
                Emoji(name: key, url: value)
            }
            .sorted { $0.name < $1.name }

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
