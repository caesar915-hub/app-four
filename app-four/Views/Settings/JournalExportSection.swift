import SwiftUI
import CryptoKit
import UniformTypeIdentifiers

/// The opaque encrypted journal blob, wrapped so `.fileExporter` can write it. The
/// bytes are AES-GCM ciphertext (`sealedBox.combined`) — there is no readable content
/// here, so a generic binary `UTType` is correct; the key lives only in memory.
struct EncryptedJournalDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.data]

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        // Import/restore is a future spec; this document is write-only for now.
        throw CocoaError(.featureUnsupported)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// One-time recovery-key surface. The key is the ONLY way to open the backup and is
/// never stored by the app, so it is shown once here — selectable and copyable — with
/// an explicit "we don't keep it" statement. Closing this is the user's acknowledgement.
struct RecoveryKeySheet: View {
    let keyBase64: String
    let onDone: () -> Void

    @State private var copied = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    Text("Keep this key safe")
                        .font(Typography.title)
                        .foregroundStyle(Theme.textPrimary)
                    Text("This file can only be opened by a future version of Squirl, using this exact key. If you lose the key, the backup can't be recovered — not even by us. Save it somewhere only you can reach.")
                        .font(Typography.body)
                        .foregroundStyle(Theme.textSecondary)
                }

                Text(keyBase64)
                    .font(.plexMono(13))
                    .foregroundStyle(Theme.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.l)
                    .background(Theme.surface2, in: .rect(cornerRadius: Radius.card))
                    .accessibilityLabel("Recovery key")
                    .accessibilityValue(keyBase64)

                Button {
                    UIPasteboard.general.setItems(
                        [[UTType.utf8PlainText.identifier: keyBase64]],
                        options: [
                            .localOnly: true,
                            .expirationDate: Date().addingTimeInterval(120)
                        ]
                    )
                    withAnimation(Motion.smooth) { copied = true }
                } label: {
                    Label(copied ? "Copied" : "Copy key", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.primary)

                Spacer()
            }
            .padding(.horizontal, Spacing.l)
            .padding(.top, Spacing.section)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
        }
    }
}
