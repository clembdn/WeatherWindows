import SwiftUI

/// Dry or rainy, shown with an icon and words as well as colour.
struct RainBadge: View {
    let exposure: Double

    var body: some View {
        let isDry = PlanText.isDry(exposure)
        Label(PlanText.rain(exposure), systemImage: isDry ? "sun.max" : "cloud.rain.fill")
            .font(.subheadline.weight(isDry ? .regular : .semibold))
            .foregroundStyle(isDry ? Color.secondary : Color.blue)
    }
}

/// Reminds the user how coarse the hourly forecast is.
struct ForecastNotice: View {
    var body: some View {
        Label(
            "Rain comes from the hourly forecast at the centre of your errands. "
                + "Scores assume it may arrive up to 30 minutes early or late.",
            systemImage: "info.circle"
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}
