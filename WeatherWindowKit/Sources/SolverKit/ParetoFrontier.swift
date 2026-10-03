/// Keeps only the items that no other item beats on both criteria (lower is better for each).
public enum ParetoFrontier {
    /// Sorted by the first criterion; among exact ties the first item given is kept.
    public static func frontier<Item>(of items: [Item], first: (Item) -> Double, second: (Item) -> Double) -> [Item] {
        let sorted = items.enumerated().sorted { lhs, rhs in
            let (a, b) = (first(lhs.element), first(rhs.element))
            if a != b { return a < b }
            let (c, d) = (second(lhs.element), second(rhs.element))
            return c != d ? c < d : lhs.offset < rhs.offset
        }

        var kept: [Item] = []
        var bestSecond = Double.infinity
        for (_, item) in sorted where second(item) < bestSecond - 1e-9 {
            kept.append(item)
            bestSecond = second(item)
        }
        return kept
    }
}
