//
//  ContentView.swift
//  Myapp
//
//  Created by 悠 on 2026/05/23.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                CalendarView()
            }
            .tabItem { Label("カレンダー", systemImage: "calendar") }

            NavigationStack {
                LensListView()
            }
            .tabItem { Label("レンズ", systemImage: "circle.grid.2x2") }

            NavigationStack {
                RepeatFilterView()
            }
            .tabItem { Label("リピ", systemImage: "arrow.triangle.2.circlepath") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("設定", systemImage: "gearshape") }
        }
        .tint(AppTheme.accent)
        .setupGate()
    }
}

// Previews are intentionally omitted in this repository environment.
