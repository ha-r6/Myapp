import Foundation
import SwiftUI

enum EyeSide: String, CaseIterable, Identifiable {
    case left
    case right

    var id: String { rawValue }

    var label: String {
        switch self {
        case .left: "左目"
        case .right: "右目"
        }
    }
}

enum AppSettingsKeys {
    static let hasCompletedSetup = "hasCompletedSetup"
    static let preferredEyeSide = "preferredEyeSide"
    static let autoCropEyeEnabled = "autoCropEyeEnabled"
}

struct SetupGateViewModifier: ViewModifier {
    @AppStorage(AppSettingsKeys.hasCompletedSetup) private var hasCompletedSetup = false
    @AppStorage(AppSettingsKeys.preferredEyeSide) private var preferredEyeSideRaw = EyeSide.right.rawValue

    @State private var showing = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                if hasCompletedSetup == false {
                    showing = true
                }
            }
            .sheet(isPresented: $showing) {
                NavigationStack {
                    InitialSetupView(
                        preferredEyeSideRaw: $preferredEyeSideRaw,
                        hasCompletedSetup: $hasCompletedSetup
                    )
                }
                .interactiveDismissDisabled()
            }
    }
}

extension View {
    func setupGate() -> some View { modifier(SetupGateViewModifier()) }
}

private struct InitialSetupView: View {
    @Binding var preferredEyeSideRaw: String
    @Binding var hasCompletedSetup: Bool

    @AppStorage(AppSettingsKeys.autoCropEyeEnabled) private var autoCropEyeEnabled = true

    var body: some View {
        List {
            Section {
                Text("最初に、写真から自動で切り抜く“目”を選んでください。後で変更もできます。")
                    .foregroundStyle(.secondary)
            }

            Section("目の切り抜き") {
                Picker("切り抜く目", selection: $preferredEyeSideRaw) {
                    ForEach(EyeSide.allCases) { side in
                        Text(side.label).tag(side.rawValue)
                    }
                }
                Toggle("自動切り抜きを使う", isOn: $autoCropEyeEnabled)
            }

            Section {
                Button {
                    hasCompletedSetup = true
                } label: {
                    Text("はじめる")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle("初期設定")
        .scrollContentBackground(.hidden)
        .background(AppTheme.subtleBackgroundGradient)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
    }
}

