/// Converts forecast values into the 0...1 rain weight shared by every rain field.
public enum RainWeight {
    /// Probability times precipitation, capped at 1 mm/h: that is already enough to soak a pedestrian.
    public static func hourly(probability: Double, precipitation: Double) -> Double {
        let chance = min(max(probability / 100, 0), 1)
        let intensity = min(max(precipitation, 0), 1)
        return chance * intensity
    }
}
