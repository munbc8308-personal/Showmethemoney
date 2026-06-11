import Foundation
import SwiftData

@Model
final class Stock {
    var symbol: String = ""
    var name: String = ""
    var market: Market = Market.kospi
    var isWatchlisted: Bool = false
    var addedAt: Date = Date()

    init(symbol: String, name: String, market: Market) {
        self.symbol = symbol
        self.name = name
        self.market = market
        self.isWatchlisted = true
        self.addedAt = Date()
    }

    var currency: Currency { market.currency }
    var broker: Broker { market.broker }
}
