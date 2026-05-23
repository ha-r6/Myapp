import SwiftUI
import PhotosUI
import UIKit

struct WearLogFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    let initialDay: Date

    @State private var selectedDay: Date
    @State private var selectedLensId: UUID?
    @State private var memo: String = ""

    @AppStorage(AppSettingsKeys.autoCropEyeEnabled) private var autoCropEyeEnabled = true
    @AppStorage(AppSettingsKeys.preferredEyeSide) private var preferredEyeSideRaw = EyeSide.right.rawValue

    @State private var indoorPickerItem: PhotosPickerItem?
    @State private var outdoorPickerItem: PhotosPickerItem?
    @State private var indoorPhotoData: Data?
    @State private var outdoorPhotoData: Data?

    @State private var showingIndoorCamera = false
    @State private var showingOutdoorCamera = false

    init(initialDay: Date) {
        self.initialDay = initialDay
        _selectedDay = State(initialValue: Calendar.current.startOfDay(for: initialDay))
    }

    var body: some View {
        Form {
            Section("基本") {
                DatePicker("日付", selection: $selectedDay, displayedComponents: [.date])
                Picker("レンズ", selection: $selectedLensId) {
                    Text("未選択").tag(UUID?.none)
                    ForEach(store.lenses) { lens in
                        Text(lens.displayName).tag(UUID?.some(lens.id))
                    }
                }
            }

            Section("着画の切り抜き") {
                Toggle("目を自動で切り抜く", isOn: $autoCropEyeEnabled)
                Picker("切り抜く目", selection: $preferredEyeSideRaw) {
                    ForEach(EyeSide.allCases) { side in
                        Text(side.label).tag(side.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("メモ") {
                TextField("着け心地・発色など（任意）", text: $memo, axis: .vertical)
            }

            Section("着画（屋内）") {
                HStack {
                    Button {
                        showingIndoorCamera = true
                    } label: {
                        Label("撮影", systemImage: "camera")
                    }
                    .buttonStyle(.bordered)

                    PhotosPicker(selection: $indoorPickerItem, matching: .images) {
                        Label(indoorPhotoData == nil ? "写真を選ぶ" : "選び直す", systemImage: "photo")
                    }
                    .buttonStyle(.bordered)

                    if indoorPhotoData != nil {
                        Button(role: .destructive) {
                            indoorPhotoData = nil
                            indoorPickerItem = nil
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                PhotoPreview(data: indoorPhotoData)
                    .frame(maxHeight: 220)
            }

            Section("着画（屋外）") {
                HStack {
                    Button {
                        showingOutdoorCamera = true
                    } label: {
                        Label("撮影", systemImage: "camera")
                    }
                    .buttonStyle(.bordered)

                    PhotosPicker(selection: $outdoorPickerItem, matching: .images) {
                        Label(outdoorPhotoData == nil ? "写真を選ぶ" : "選び直す", systemImage: "photo")
                    }
                    .buttonStyle(.bordered)

                    if outdoorPhotoData != nil {
                        Button(role: .destructive) {
                            outdoorPhotoData = nil
                            outdoorPickerItem = nil
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                PhotoPreview(data: outdoorPhotoData)
                    .frame(maxHeight: 220)
            }
        }
        .navigationTitle("記録追加")
        .scrollContentBackground(.hidden)
        .background(AppTheme.subtleBackgroundGradient)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    save()
                    dismiss()
                }
            }
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(AppTheme.background, for: .navigationBar)
        .task(id: indoorPickerItem) {
            indoorPhotoData = await loadAndMaybeCrop(from: indoorPickerItem)
        }
        .task(id: outdoorPickerItem) {
            outdoorPhotoData = await loadAndMaybeCrop(from: outdoorPickerItem)
        }
        .fullScreenCover(isPresented: $showingIndoorCamera) {
            CameraPicker(
                onPick: { image in
                    showingIndoorCamera = false
                    guard let image else { return }
                    Task { @MainActor in
                        indoorPhotoData = await maybeCropUIImage(image)
                    }
                },
                onCancel: {
                    showingIndoorCamera = false
                }
            )
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showingOutdoorCamera) {
            CameraPicker(
                onPick: { image in
                    showingOutdoorCamera = false
                    guard let image else { return }
                    Task { @MainActor in
                        outdoorPhotoData = await maybeCropUIImage(image)
                    }
                },
                onCancel: {
                    showingOutdoorCamera = false
                }
            )
            .ignoresSafeArea()
        }
    }

    private func save() {
        let day = Calendar.current.startOfDay(for: selectedDay)
        let log = WearLog(
            day: day,
            lensId: selectedLensId,
            memo: memo,
            indoorPhotoData: indoorPhotoData,
            outdoorPhotoData: outdoorPhotoData
        )
        store.addWearLog(log)
    }

    private func loadAndMaybeCrop(from item: PhotosPickerItem?) async -> Data? {
        guard let item else { return nil }
        // PhotosPicker の結果は HEIC のこともあるので、まずは Data をそのまま保存（JPEG 以外でも表示は可能）
        guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }

        guard autoCropEyeEnabled else { return data }
        let side = EyeSide(rawValue: preferredEyeSideRaw) ?? .right
        return await EyeCropper.cropPreferredEye(from: data, side: side) ?? data
    }

    private func maybeCropUIImage(_ image: UIImage) async -> Data? {
        guard let data = image.jpegData(compressionQuality: 0.92) else { return nil }
        guard autoCropEyeEnabled else { return data }
        let side = EyeSide(rawValue: preferredEyeSideRaw) ?? .right
        return await EyeCropper.cropPreferredEye(from: data, side: side) ?? data
    }
}

private struct PhotoPreview: View {
    let data: Data?

    var body: some View {
        if let data, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            Text("—")
                .foregroundStyle(.secondary)
        }
    }
}

// Previews are intentionally omitted in this repository environment.
