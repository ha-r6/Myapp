import SwiftUI

struct DestructiveConfirmationDialog: View {
    let title: String
    let message: String
    let cancelTitle: String
    let destructiveTitle: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }

            VStack(spacing: 14) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 14) {
                    Button(cancelTitle) {
                        onCancel()
                    }
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color(uiColor: .darkGray))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color(uiColor: .systemGray5))
                    .clipShape(Capsule())

                    Button(destructiveTitle) {
                        onConfirm()
                    }
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color(uiColor: .systemGray5))
                    .clipShape(Capsule())
                }
            }
            .padding(28)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 22, x: 0, y: 10)
            .padding(.horizontal, 20)
        }
    }
}
