import SwiftUI

/// Settings ▸ "iCloud Sync" section (spec 038, US1). Native grouped-`List` chrome
/// (DESIGN.md — Settings is SF/List-exempt). Off by default (FR-001); enabling is
/// gated behind a consent sheet (FR-003). Mockup: html-mockups/038-settings-icloud-sync.html.
struct ICloudSyncSection: View {
    @State private var viewModel = SyncSettingsViewModel()
    @State private var showRemoveConfirm = false

    var body: some View {
        @Bindable var viewModel = viewModel

        Section {
            Toggle(isOn: syncBinding) {
                Text("Sync with iCloud")
                    .font(Typography.body)
                    .foregroundStyle(NewLook.inkPrimary)
            }
            .tint(Theme.meadowGreen)
            // Can't enable without an available iCloud account; leave interactive when
            // already on so the user can always turn it off.
            .disabled(!viewModel.canEnable && !viewModel.isOn)

            if viewModel.isOn {
                Button("Remove My Data from iCloud", role: .destructive) {
                    showRemoveConfirm = true
                }
            }
        } header: {
            Text("iCloud Sync")
        } footer: {
            Text(viewModel.footer)
        }
        .task { await viewModel.refresh() }
        .sheet(isPresented: $viewModel.showConsent) {
            SyncConsentSheet(
                onConfirm: { Task { await viewModel.confirmEnable() } },
                onCancel: viewModel.cancelConsent
            )
        }
        .confirmationDialog(
            "Remove your journal from iCloud?",
            isPresented: $showRemoveConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove from iCloud", role: .destructive) { Task { await viewModel.remove() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes the copy in iCloud. Your journal on this device is kept, and your other devices keep theirs.")
        }
        .alert("Sync", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    /// Gated toggle: flipping ON opens the consent sheet (the flag is written only on
    /// confirm), so the switch reflects the true enabled state and snaps back if cancelled.
    private var syncBinding: Binding<Bool> {
        Binding(get: { viewModel.isOn }, set: { viewModel.setToggle($0) })
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })
    }
}

/// Pre-enable consent (FR-003/FR-012). States what syncs, that it goes to the user's
/// own iCloud, that Squirl can't read it, and the ADP-conditional encryption claim.
private struct SyncConsentSheet: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    Text("Your journal syncs across your Apple devices, automatically in the background.")
                        .font(Typography.body)
                        .foregroundStyle(NewLook.inkSecondary)

                    VStack(alignment: .leading, spacing: Spacing.m) {
                        point("Your check-ins, transcripts, moods and medication log sync. Audio stays on its device.")
                        point("It goes only to your own iCloud account. No account, and no Squirl server.")
                        point("Squirl can’t read it. The developer has no access to your data.")
                    }

                    Text("End-to-end encryption is on when you’ve enabled Advanced Data Protection in your Apple Account. Otherwise your data is private to your iCloud account and still unreadable by Squirl.")
                        .font(Typography.callout)
                        .foregroundStyle(NewLook.inkSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.xl)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: Spacing.s) {
                    Button(action: onConfirm) {
                        Text("Turn On Sync")
                            .font(Typography.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.m)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.meadowGreen)

                    Button("Not Now", action: onCancel)
                        .font(Typography.body)
                        .foregroundStyle(NewLook.inkSecondary)
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.m)
                .background(.bar)
            }
            .navigationTitle("Sync with iCloud?")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func point(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
            Image(systemName: "checkmark")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.meadowGreen)
            Text(text)
                .font(Typography.body)
                .foregroundStyle(NewLook.inkPrimary)
        }
    }
}
