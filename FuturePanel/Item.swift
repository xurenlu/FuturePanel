//
//  Item.swift
//  FuturePanel
//
//  Created by rocky on 2025/9/8.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
