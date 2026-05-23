//
//  MyappApp.swift
//  Myapp
//
//  Created by 悠 on 2026/05/23.
//

import SwiftUI

@main
struct MyappApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
