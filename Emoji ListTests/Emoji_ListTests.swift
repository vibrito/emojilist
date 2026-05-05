//
//  Emoji_ListTests.swift
//  Emoji ListTests
//
//  Created by MLBBR-MAC-VINICIUS on 02/05/26.
//

import Testing
import CoreData
import Foundation
@testable import Emoji_List

struct Emoji_ListTests {

    @Test func decodesEmojiResponse() throws {
        let data = try #require("""
        {
            "shipit": "https://github.githubassets.com/images/icons/emoji/shipit.png?v8",
            "octocat": "https://github.githubassets.com/images/icons/emoji/octocat.png?v8"
        }
        """.data(using: .utf8))

        let response = try JSONDecoder().decode(EmojiResponse.self, from: data)

        #expect(response["shipit"] == "https://github.githubassets.com/images/icons/emoji/shipit.png?v8")
        #expect(response["octocat"] == "https://github.githubassets.com/images/icons/emoji/octocat.png?v8")
    }

    @Test func decodesUserAvatarResponse() throws {
        let data = try #require("""
        {
            "login": "blissapps",
            "id": 223156,
            "avatar_url": "https://avatars0.githubusercontent.com/u/223156?v=4"
        }
        """.data(using: .utf8))

        let response = try JSONDecoder().decode(UserAvatarResponse.self, from: data)

        #expect(response.login == "blissapps")
        #expect(response.id == 223156)
        #expect(response.avatarURL == "https://avatars0.githubusercontent.com/u/223156?v=4")
    }

    @Test func decodesAppleReposResponse() throws {
        let data = try #require("""
        [
            {
                "id": 170908616,
                "full_name": "apple/.github",
                "private": false,
                "description": "Apple organization profile"
            }
        ]
        """.data(using: .utf8))

        let repos = try JSONDecoder().decode([AppleRepo].self, from: data)
        let repo = try #require(repos.first)

        #expect(repo.id == 170908616)
        #expect(repo.fullName == "apple/.github")
        #expect(repo.isPrivate == false)
        #expect(repo.description == "Apple organization profile")
    }

    @MainActor
    @Test func inMemoryStorePersistsEmojiAndAvatar() throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.viewContext

        let emoji = EmojiItem(context: context)
        emoji.name = "shipit"
        emoji.url = "https://github.githubassets.com/images/icons/emoji/shipit.png?v8"
        emoji.imageData = Data([1, 2, 3])

        let avatar = UserAvatar(context: context)
        avatar.login = "blissapps"
        avatar.githubID = 223156
        avatar.avatarURL = "https://avatars0.githubusercontent.com/u/223156?v=4"
        avatar.avatarData = Data([4, 5, 6])

        try context.save()

        let emojiRequest: NSFetchRequest<EmojiItem> = EmojiItem.fetchRequest()
        let storedEmojis = try context.fetch(emojiRequest)

        let avatarRequest: NSFetchRequest<UserAvatar> = UserAvatar.fetchRequest()
        let storedAvatars = try context.fetch(avatarRequest)

        #expect(storedEmojis.count == 1)
        #expect(storedEmojis.first?.name == "shipit")
        #expect(storedEmojis.first?.imageData == Data([1, 2, 3]))
        #expect(storedAvatars.count == 1)
        #expect(storedAvatars.first?.login == "blissapps")
        #expect(storedAvatars.first?.githubID == 223156)
        #expect(storedAvatars.first?.avatarData == Data([4, 5, 6]))
    }

}
