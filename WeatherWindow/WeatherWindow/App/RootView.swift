//
//  RootView.swift
//  WeatherWindow
//
//  Created by Clement Boudon on 7/10/2026.
//

import SwiftUI

struct RootView: View {
    @AppStorage("replayMode") private var replayMode = false

    var body: some View {
        VStack(spacing: 0) {
            if replayMode {
                ReplayBanner()
            }
            TabView {
                Tab("Plan", systemImage: "map") {
                    DayPlanView()
                }
                Tab("Errands", systemImage: "checklist") {
                    ErrandListView()
                }
                Tab("About", systemImage: "info.circle") {
                    AboutView()
                }
            }
        }
    }
}
