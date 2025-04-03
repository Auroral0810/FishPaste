//
//  Item.swift
//  FishCopy
//
//  Created by 俞云烽 on 2025/04/02.
//

import Foundation
import SwiftData

@Model
final class LegacyItem {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
