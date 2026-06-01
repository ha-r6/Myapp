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
                LensListView()
            }
            .tabItem { Label("図鑑", systemImage: "circle.grid.2x2") }

            NavigationStack {
                CalendarView()
            }
            .tabItem { Label("カレンダー", systemImage: "calendar") }

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
