import Foundation
import Testing
@testable import ForecastKit

@Test(arguments: [
    (60.0, 0.5, 0.3),
    (100.0, 3.0, 1.0),
    (0.0, 2.0, 0.0)
])
func rainWeightExamples(probability: Double, precipitation: Double, expected: Double) {
    let weight = RainWeight.hourly(probability: probability, precipitation: precipitation)
    #expect(abs(weight - expected) < 1e-9)
}
