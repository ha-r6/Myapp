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
    static let fixedPowerEnabled = "fixedPowerEnabled"
    static let fixedPowerValue = "fixedPowerValue"
    static let fixedLeftPowerValue = "fixedLeftPowerValue"
    static let fixedRightPowerValue = "fixedRightPowerValue"
    static let recentPurchasePlaces = "recentPurchasePlaces"
    static let lastLeftPower = "lastLeftPower"
    static let lastRightPower = "lastRightPower"
    static let aiSpecLookupEnabled = "aiSpecLookupEnabled"
}

struct SetupGateViewModifier: ViewModifier {
    @AppStorage(AppSettingsKeys.hasCompletedSetup) private var hasCompletedSetup = false

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
                    InitialSetupView(hasCompletedSetup: $hasCompletedSetup)
                }
                .interactiveDismissDisabled()
            }
    }
}

extension View {
    func setupGate() -> some View { modifier(SetupGateViewModifier()) }
}

private struct InitialSetupView: View {
    @Binding var hasCompletedSetup: Bool

    @AppStorage(AppSettingsKeys.fixedPowerEnabled) private var fixedPowerEnabled = false
    @AppStorage(AppSettingsKeys.fixedPowerValue) private var fixedPowerValue = ""
    @AppStorage(AppSettingsKeys.fixedLeftPowerValue) private var fixedLeftPowerValue = ""
    @AppStorage(AppSettingsKeys.fixedRightPowerValue) private var fixedRightPowerValue = ""

    private enum PowerChoice: Hashable, Identifiable {
        case unselected
        case manual
        case value(Double)

        var id: String {
            switch self {
            case .unselected: "unselected"
            case .manual: "manual"
            case .value(let v): "value:\(String(format: "%.2f", v))"
            }
        }

        var label: String {
            switch self {
            case .unselected: "選択する"
            case .manual: "手入力"
            case .value(let v): String(format: "%.2f", v)
            }
        }

        var doubleValue: Double? {
            switch self {
            case .value(let v): v
            case .unselected, .manual: nil
            }
        }
    }

    private var powerOptions: [Double] { stride(from: 0.0, through: -10.0, by: -0.25).map { ($0 * 100).rounded() / 100 } }
    @State private var leftChoice: PowerChoice = .unselected
    @State private var rightChoice: PowerChoice = .unselected
    @State private var isInitializing = true

    var body: some View {
        List {
            Section {
                Text("最初に度数の固定などを設定します。後で変更もできます。")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("度数を固定する", isOn: $fixedPowerEnabled)
                if fixedPowerEnabled {
                    Picker("左", selection: $leftChoice) {
                        Text(PowerChoice.unselected.label).tag(PowerChoice.unselected)
                        ForEach(powerOptions, id: \.self) { v in
                            Text(String(format: "%.2f", v)).tag(PowerChoice.value(v))
                        }
                        Text(PowerChoice.manual.label).tag(PowerChoice.manual)
                    }
                    .pickerStyle(.menu)
                    if leftChoice == .manual {
                        TextField("左（例: -3.25）", text: $fixedLeftPowerValue)
                            .keyboardType(.numbersAndPunctuation)
                    }

                    Picker("右", selection: $rightChoice) {
                        Text(PowerChoice.unselected.label).tag(PowerChoice.unselected)
                        ForEach(powerOptions, id: \.self) { v in
                            Text(String(format: "%.2f", v)).tag(PowerChoice.value(v))
                        }
                        Text(PowerChoice.manual.label).tag(PowerChoice.manual)
                    }
                    .pickerStyle(.menu)
                    if rightChoice == .manual {
                        TextField("右（例: -3.25）", text: $fixedRightPowerValue)
                            .keyboardType(.numbersAndPunctuation)
                    }
                }
            } header: {
                Text("度数")
            } footer: {
                Text("度数を固定すると、レンズ登録時に左右それぞれの固定値が自動で表示されます。")
                    .foregroundStyle(.secondary)
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
        .onAppear {
            isInitializing = true
            let legacy = fixedPowerValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if legacy.isEmpty == false {
                if fixedLeftPowerValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { fixedLeftPowerValue = legacy }
                if fixedRightPowerValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { fixedRightPowerValue = legacy }
            }
            leftChoice = choice(from: fixedLeftPowerValue)
            rightChoice = choice(from: fixedRightPowerValue)
            isInitializing = false
        }
        .onChange(of: leftChoice) { old, next in
            if isInitializing { return }
            switch next {
            case .unselected:
                fixedLeftPowerValue = ""
            case .manual:
                if old != .manual { fixedLeftPowerValue = "" }
            case .value(let v):
                fixedLeftPowerValue = String(format: "%.2f", v)
            }
        }
        .onChange(of: rightChoice) { old, next in
            if isInitializing { return }
            switch next {
            case .unselected:
                fixedRightPowerValue = ""
            case .manual:
                if old != .manual { fixedRightPowerValue = "" }
            case .value(let v):
                fixedRightPowerValue = String(format: "%.2f", v)
            }
        }
    }

    private func choice(from raw: String) -> PowerChoice {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return .unselected }
        if let value = Double(trimmed), powerOptions.contains(where: { abs($0 - value) < 0.001 }) {
            return .value(value)
        }
        return .manual
    }
}
