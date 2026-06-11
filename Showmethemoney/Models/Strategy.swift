import Foundation
import SwiftData

@Model
final class Strategy {
    var name: String = ""
    var type: StrategyType = StrategyType.momentum
    var targetSymbols: [String] = []
    var positionSizePct: Double = 10.0
    var stopLossPct: Double = 5.0
    var takeProfitPct: Double = 10.0
    var rebalancePeriod: RebalancePeriod = RebalancePeriod.daily
    var isActive: Bool = false
    var createdAt: Date = Date()
    var memo: String = ""

    @Relationship(deleteRule: .cascade) var conditions: [Condition] = []

    init(name: String, type: StrategyType) {
        self.name = name
        self.type = type
    }

    var buyConditions: [Condition] { conditions.filter { $0.isBuyCondition } }
    var sellConditions: [Condition] { conditions.filter { !$0.isBuyCondition } }
}
