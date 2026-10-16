//
//  ItinerariesView.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 16/10/2026.
//

import SwiftData
import SwiftUI

struct ItinerariesView: View {
    let onSelect: (DayPlan) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DayPlan.departure, order: .reverse) private var savedPlans: [DayPlan]

    private var itineraries: [DayPlan] {
        var seenRoutes: [String] = []
        var found: [DayPlan] = []
        for plan in savedPlans {
            let route = plan.startName + " " + routeText(of: plan)
            let hasErrands = plan.stops.contains { $0.errand != nil }
            if hasErrands && !seenRoutes.contains(route) {
                seenRoutes.append(route)
                found.append(plan)
            }
        }
        return found
    }

    var body: some View {
        List {
            ForEach(itineraries) { plan in
                Button {
                    onSelect(plan)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(routeText(of: plan))
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("From \(plan.start.name) · to \(plan.end.name)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Last done \(plan.departure.formatted(.dateTime.weekday(.wide).day().month()))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .overlay {
            if itineraries.isEmpty {
                ContentUnavailableView("No Saved Itineraries", systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                                       description: Text("Save a plan from its itinerary, then reuse it here."))
            }
        }
        .navigationTitle("Saved Itineraries")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func routeText(of plan: DayPlan) -> String {
        plan.orderedStops.map(\.name).joined(separator: " → ")
    }
}
