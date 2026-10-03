/// Converts forecast values into the 0...1 rain weight shared by every rain field.
public enum RainWeight {
    /// Rain rate at which a pedestrian counts as fully wet.
    public static let saturatingRate = 1.0

    /// Weight of an hourly forecast: probability times precipitation, capped at 1 mm/h.
    public static func hourly(probability: Double, precipitation: Double) -> Double {
        let chance = min(max(probability / 100, 0), 1)
        let intensity = min(max(precipitation / saturatingRate, 0), 1)
        return chance * intensity
    }
}
