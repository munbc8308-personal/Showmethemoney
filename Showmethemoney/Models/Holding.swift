import Foundation
import SwiftData

@Model
final class Holding {
    var symbol: String = ""
    var stockName: String = ""
    var market: Market = Market.kospi
    var broker: Broker = Broker.kis
    var quantity: Int = 0
    var averageCost: Double = 0.0
    var updatedAt: Date = Date()

    init(
        symbol: String,
        stockName: String,
        market: Market,
        broker: Broker,
        quantity: Int,
        averageCost: Double
    ) {
        self.symbol = symbol
        self.stockName = stockName
        self.market = market
        self.broker = broker
        self.quantity = quantity
        self.averageCost = averageCost
        self.updatedAt = Date()
    }

    var totalCost: Double { averageCost * Double(quantity) }
    var currency: Currency { market.currency }
}
