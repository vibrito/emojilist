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
}

extension EmojiItem: Identifiable {}
