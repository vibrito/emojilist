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
    @State private var username = ""
    @State private var selectedUserLogin: String?
    @State private var selectedUserAvatarData: Data?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        NavigationLink("Emoji List") {
                            EmojiGridView()
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.bordered)

                        Button("Random Emoji") {
                            Task {
                                await showRandomEmoji()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.bordered)

                        NavigationLink("Avatar List") {
                            AvatarGridView()
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.bordered)

                        NavigationLink("Apple Repos") {
                            AppleRepoListView()
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.bordered)
                    }

                    HStack(spacing: 12) {
                        TextField("Username", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)

                        Button("Search") {
                            Task {
                                await searchUserAvatar()
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

                    if let selectedUserLogin, let selectedUserAvatarData,
                       let avatarImage = UIImage(data: selectedUserAvatarData) {
                        VStack(spacing: 12) {
                            Image(uiImage: avatarImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 96, height: 96)

                            Text(selectedUserLogin)
                                .font(.headline)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Emoji")
        }
    }

    @MainActor
    func searchUserAvatar() async {
        let searchTerm = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchTerm.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            if let cachedUser = try fetchCachedUser(login: searchTerm),
               let avatarData = cachedUser.avatarData {
                selectedUserLogin = cachedUser.login
                selectedUserAvatarData = avatarData
                isLoading = false
                return
            }

            let response = try await GitHubAPIClient.shared.fetchUserAvatar(login: searchTerm)
            let avatarData = try await GitHubAPIClient.shared.fetchImageData(from: response.avatarURL)
            let userAvatar = try saveUserAvatar(response, avatarData: avatarData)

            selectedUserLogin = userAvatar.login
            selectedUserAvatarData = userAvatar.avatarData
        } catch {
            errorMessage = error.localizedDescription
            selectedUserLogin = nil
            selectedUserAvatarData = nil
        }

        isLoading = false
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

        do {
            let response = try await GitHubAPIClient.shared.fetchEmojis()
            try saveEmojis(response)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func saveEmojis(_ response: EmojiResponse) throws {
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

    private func saveUserAvatar(_ response: UserAvatarResponse, avatarData: Data) throws -> UserAvatar {
        let userAvatar = try fetchCachedUser(login: response.login) ?? UserAvatar(context: viewContext)
        userAvatar.login = response.login
        userAvatar.githubID = Int64(response.id)
        userAvatar.avatarURL = response.avatarURL
        userAvatar.avatarData = avatarData

        try viewContext.save()
        return userAvatar
    }

    private func fetchCachedUser(login: String) throws -> UserAvatar? {
        let request: NSFetchRequest<UserAvatar> = UserAvatar.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "login =[c] %@", login)

        return try viewContext.fetch(request).first
    }
}

struct AppleRepoListView: View {
    @State private var repos: [AppleRepo] = []
    @State private var page = 1
    @State private var isLoading = false
    @State private var canLoadMore = true
    @State private var errorMessage: String?

    var body: some View {
        List {
            ForEach(repos) { repo in
                VStack(alignment: .leading, spacing: 6) {
                    Text(repo.fullName)
                        .font(.headline)

                    Text(repo.isPrivate ? "Private" : "Public")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let description = repo.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
                .onAppear {
                    if repo.id == repos.last?.id {
                        Task {
                            await loadRepos()
                        }
                    }
                }
            }

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
        }
        .navigationTitle("Apple Repos")
        .task {
            await loadRepos()
        }
    }

    @MainActor
    private func loadRepos() async {
        guard !isLoading, canLoadMore else { return }

        isLoading = true
        errorMessage = nil

        do {
            let newRepos = try await GitHubAPIClient.shared.fetchAppleRepos(page: page)
            repos.append(contentsOf: newRepos)
            page += 1
            canLoadMore = newRepos.count == 10
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
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

struct AvatarGridView: View {
    @Environment(\.managedObjectContext) private var viewContext

    private let columns = [
        GridItem(.adaptive(minimum: 96), spacing: 16)
    ]

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \UserAvatar.login, ascending: true)],
        animation: .default)
    private var avatars: FetchedResults<UserAvatar>

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(avatars) { avatar in
                    Button {
                        delete(avatar)
                    } label: {
                        VStack(spacing: 8) {
                            if let avatarData = avatar.avatarData,
                               let avatarImage = UIImage(data: avatarData) {
                                Image(uiImage: avatarImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 48, height: 48)
                            } else {
                                ProgressView()
                                    .frame(width: 48, height: 48)
                            }

                            Text(avatar.login ?? "")
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
        .navigationTitle("Avatar List")
    }

    private func delete(_ avatar: UserAvatar) {
        viewContext.delete(avatar)

        do {
            try viewContext.save()
        } catch {
            viewContext.rollback()
        }
    }
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

        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let data = try await GitHubAPIClient.shared.fetchImageData(from: url)

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
