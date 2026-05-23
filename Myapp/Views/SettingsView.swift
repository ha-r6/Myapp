import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettingsKeys.preferredEyeSide) private var preferredEyeSideRaw = EyeSide.right.rawValue
    @AppStorage(AppSettingsKeys.autoCropEyeEnabled) private var autoCropEyeEnabled = true

    @AppStorage(LensCardSettingsKeys.enabledFields) private var enabledFieldsRaw = LensCardDisplaySettings.serialize(LensCardDisplaySettings.defaultEnabled)

    private var enabled: Set<LensCardField> {
        LensCardDisplaySettings.enabledFields(from: enabledFieldsRaw)
    }

    var body: some View {
        List {
            Section("目の切り抜き") {
                Toggle("自動切り抜きを使う", isOn: $autoCropEyeEnabled)
                Picker("切り抜く目", selection: $preferredEyeSideRaw) {
                    ForEach(EyeSide.allCases) { side in
                        Text(side.label).tag(side.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("レンズカード表示") {
                ForEach(LensCardField.allCases) { field in
                    Toggle(field.label, isOn: Binding(
                        get: { enabled.contains(field) },
                        set: { isOn in
                            var next = enabled
                            if isOn { next.insert(field) } else { next.remove(field) }
                            enabledFieldsRaw = LensCardDisplaySettings.serialize(next)
                        }
                    ))
                }
            }
        }
        .navigationTitle("設定")
        .scrollContentBackground(.hidden)
        .background(AppTheme.subtleBackgroundGradient)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
    }
}

