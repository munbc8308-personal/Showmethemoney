//
//  Item.swift
//  Showmethemoney
//
//  Created by 문병천 on 6/10/26.
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
