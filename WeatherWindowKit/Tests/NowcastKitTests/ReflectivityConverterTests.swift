import Foundation
import Testing
@testable import NowcastKit

@Test(arguments: [
    (20.0, 0.65),
    (30.0, 2.73),
    (40.0, 11.5)
])
func convertsReflectivityToRainRate(dBZ: Double, expected: Double) {
    #expect(abs(ReflectivityConverter.rainRate(dBZ: dBZ) - expected) <= 0.05)
}
