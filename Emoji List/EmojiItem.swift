//
//  EmojiItem.swift
//  Emoji List
//
//  Created by MLBBR-MAC-VINICIUS on 02/05/26.
//

import CoreData
import Foundation

@objc(EmojiItem)
public class EmojiItem: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<EmojiItem> {
        NSFetchRequest<EmojiItem>(entityName: "EmojiItem")
    }

    @NSManaged public var name: String?
    @NSManaged public var url: String?
    @NSManaged public var imageData: Data?
}

extension EmojiItem: Identifiable {}

@objc(UserAvatar)
public class UserAvatar: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserAvatar> {
        NSFetchRequest<UserAvatar>(entityName: "UserAvatar")
    }

    @NSManaged public var avatarData: Data?
    @NSManaged public var avatarURL: String?
    @NSManaged public var githubID: Int64
    @NSManaged public var login: String?
}

extension UserAvatar: Identifiable {}
