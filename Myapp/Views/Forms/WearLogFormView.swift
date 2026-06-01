import SwiftUI
import PhotosUI
import UIKit

struct WearLogFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    let initialDay: Date
    private let editingWearLog: WearLog?

    @State private var selectedDay: Date
    @State private var selectedLensId: UUID?
    @State private var memo: String = ""

    @State private var indoorPickerItem: PhotosPickerItem?
    @State private var outdoorPickerItem: PhotosPickerItem?
    @State private var indoorPhotoData: Data?
    @State private var outdoorPhotoData: Data?

    @State private var showingIndoorCamera = false
    @State private var showingOutdoorCamera = false

    init(initialDay: Date, editing: WearLog? = nil) {
        self.initialDay = initialDay
        self.editingWearLog = editing
        _selectedDay = State(initialValue: Calendar.current.startOfDay(for: initialDay))
    }

    var body: some View {
        Form {
            Section("基本") {
                DatePicker("日付", selection: $selectedDay, displayedComponents: [.date])
                LensHorizontalPicker(
                    selectedLensId: $selectedLensId,
                    lenses: store.lenses
                )
                .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 6, trailing: 0))
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
            indoorPhotoData = await loadPhotoData(from: indoorPickerItem)
        }
        .task(id: outdoorPickerItem) {
            outdoorPhotoData = await loadPhotoData(from: outdoorPickerItem)
        }
        .fullScreenCover(isPresented: $showingIndoorCamera) {
            CameraPicker(
                onPick: { image in
                    showingIndoorCamera = false
                    guard let image else { return }
                    Task { @MainActor in
                        indoorPhotoData = image.jpegData(compressionQuality: 0.92)
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
                        outdoorPhotoData = image.jpegData(compressionQuality: 0.92)
                    }
                },
                onCancel: {
                    showingOutdoorCamera = false
                }
            )
            .ignoresSafeArea()
        }
        .onAppear {
            guard let log = editingWearLog else { return }
            selectedDay = Calendar.current.startOfDay(for: log.day)
            selectedLensId = log.lensId
            memo = log.memo
            indoorPhotoData = log.indoorPhotoData
            outdoorPhotoData = log.outdoorPhotoData
        }
    }

    private func save() {
        let day = Calendar.current.startOfDay(for: selectedDay)
        if var editingWearLog {
            editingWearLog.day = day
            editingWearLog.lensId = selectedLensId
            editingWearLog.memo = memo
            editingWearLog.indoorPhotoData = indoorPhotoData
            editingWearLog.outdoorPhotoData = outdoorPhotoData
            store.upsertWearLog(editingWearLog)
        } else {
            let log = WearLog(
                day: day,
                lensId: selectedLensId,
                memo: memo,
                indoorPhotoData: indoorPhotoData,
                outdoorPhotoData: outdoorPhotoData
            )
            store.addWearLog(log)
        }
    }

    private func loadPhotoData(from item: PhotosPickerItem?) async -> Data? {
        guard let item else { return nil }
        // PhotosPicker の結果は HEIC のこともあるので、まずは Data をそのまま保存（JPEG 以外でも表示は可能）
        guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
        return data
    }
}

private struct LensHorizontalPicker: View {
    @Binding var selectedLensId: UUID?
    let lenses: [Lens]

    @State private var showingAddLens = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("レンズ")
                    .font(.headline)
                Spacer()
                if selectedLensId != nil {
                    Button("未選択に戻す") {
                        selectedLensId = nil
                    }
                    .font(.subheadline)
                }
            }
            if lenses.isEmpty {
                ContentUnavailableView("レンズがありません", systemImage: "circle.dotted")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(lenses) { lens in
                            LensSelectableCard(
                                lens: lens,
                                isSelected: selectedLensId == lens.id
                            )
                            .onTapGesture {
                                selectedLensId = lens.id
                            }
                        }

                        AddLensCard()
                            .onTapGesture { showingAddLens = true }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .frame(height: 260)
            }
        }
        .sheet(isPresented: $showingAddLens) {
            NavigationStack {
                LensFormView(prefillSuggestion: nil)
            }
        }
    }
}

private struct LensSelectableCard: View {
    let lens: Lens
    let isSelected: Bool

    var body: some View {
        let cardWidth: CGFloat = 180
        ZStack {
            LensStickerCard(lens: lens)
                .scaleEffect(0.94)
                .frame(width: cardWidth)

            if isSelected {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.accent, lineWidth: 3)
                    .frame(width: cardWidth)
            }
        }
        .animation(.easeInOut(duration: 0.16), value: isSelected)
    }
}

private struct AddLensCard: View {
    var body: some View {
        let cardWidth: CGFloat = 180
        VStack(spacing: 12) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.accent)

            Text("新規登録")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(width: cardWidth, height: 240)
        .scaleEffect(0.94)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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
