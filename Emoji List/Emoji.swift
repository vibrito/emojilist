//
//  Untitled.swift
//  Emoji List
//
//  Created by MLBBR-MAC-VINICIUS on 02/05/26.
//

import CoreData

typealias EmojiResponse = [String: String]

struct Emoji: Identifiable {
    let id = UUID()
    let name: String
    let url: String
}
