import Foundation
import SwiftData

@Model
final class Trade {
    var symbol: String = ""
    var stockName: String = ""
    var market: Market = Market.kospi
    var broker: Broker = Broker.kis
    var type: TradeType = TradeType.buy
    var price: Double = 0.0
    var quantity: Int = 0
    var executedAt: Date = Date()
    var strategyName: String = ""
    var profit: Double? = nil
    var profitPct: Double? = nil
    var orderId: String = ""

    init(
        symbol: String,
        stockName: String,
        market: Market,
        broker: Broker,
        type: TradeType,
        price: Double,
        quantity: Int,
        strategyName: String,
        orderId: String = ""
    ) {
        self.symbol = symbol
        self.stockName = stockName
        self.market = market
        self.broker = broker
        self.type = type
        self.price = price
        self.quantity = quantity
        self.strategyName = strategyName
        self.orderId = orderId
    }

    var totalAmount: Double { price * Double(quantity) }
    var currency: Currency { market.currency }
}
