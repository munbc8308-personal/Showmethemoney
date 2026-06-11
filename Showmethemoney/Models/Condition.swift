import Foundation
import SwiftData

@Model
final class Condition {
    var indicator: ConditionIndicator = ConditionIndicator.rsi
    var conditionOperator: ConditionOperator = ConditionOperator.lessThan
    var value: Double = 30.0
    var period: Int = 14
    var isBuyCondition: Bool = true

    var strategy: Strategy?

    init(
        indicator: ConditionIndicator,
        conditionOperator: ConditionOperator,
        value: Double,
        period: Int = 14,
        isBuyCondition: Bool = true
    ) {
        self.indicator = indicator
        self.conditionOperator = conditionOperator
        self.value = value
        self.period = period
        self.isBuyCondition = isBuyCondition
    }

    var displayText: String {
        "\(indicator.rawValue)(\(period)) \(conditionOperator.rawValue) \(value)"
    }
}
