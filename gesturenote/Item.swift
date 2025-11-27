//
//  Item.swift
//  gesturenote
//
//  Created by EnchantedBroccoli on 11/27/25.
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
