//
//  GitHubAPIClient.swift
//  Emoji List
//
//  Created by MLBBR-MAC-VINICIUS on 05/05/26.
//

import Foundation

final class GitHubAPIClient {
    static let shared = GitHubAPIClient()

    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared, decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.decoder = decoder
    }

    func fetchEmojis() async throws -> EmojiResponse {
        let url = try makeURL("https://api.github.com/emojis")
        let data = try await fetchData(from: url)
        return try decoder.decode(EmojiResponse.self, from: data)
    }

    func fetchUserAvatar(login: String) async throws -> UserAvatarResponse {
        guard let escapedLogin = login.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw URLError(.badURL)
        }

        let url = try makeURL("https://api.github.com/users/\(escapedLogin)")
        let (data, response) = try await session.data(from: url)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
            throw UserAvatarError.notFound
        }

        return try decoder.decode(UserAvatarResponse.self, from: data)
    }

    func fetchAppleRepos(page: Int, perPage: Int = 10) async throws -> [AppleRepo] {
        var components = URLComponents(string: "https://api.github.com/orgs/apple/repos")
        components?.queryItems = [
            URLQueryItem(name: "per_page", value: "\(perPage)"),
            URLQueryItem(name: "page", value: "\(page)")
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        let data = try await fetchData(from: url)
        return try decoder.decode([AppleRepo].self, from: data)
    }

    func fetchImageData(from urlString: String) async throws -> Data {
        let url = try makeURL(urlString)
        return try await fetchData(from: url)
    }

    private func fetchData(from url: URL) async throws -> Data {
        let (data, _) = try await session.data(from: url)
        return data
    }

    private func makeURL(_ urlString: String) throws -> URL {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        return url
    }
}

struct UserAvatarResponse: Decodable {
    let login: String
    let id: Int
    let avatarURL: String

    enum CodingKeys: String, CodingKey {
        case login
        case id
        case avatarURL = "avatar_url"
    }
}

enum UserAvatarError: LocalizedError {
    case notFound

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "User not found"
        }
    }
}

struct AppleRepo: Decodable, Identifiable {
    let id: Int
    let fullName: String
    let isPrivate: Bool
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case isPrivate = "private"
        case description
    }
}
