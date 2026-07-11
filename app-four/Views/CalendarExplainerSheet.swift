import SwiftUI

struct CalendarExplainerSheet: View {
    var onFinished: () -> Void

    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss

    @AppStorage(CalendarPreferences.Keys.calendarTitlesIncluded) private var titlesIncluded = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                grabHandle

                eyebrow

                Text("Remember what each day held")
                    .font(Typography.title)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.bottom, Spacing.l)

                infoRows
                    .padding(.bottom, Spacing.l)

                titlesToggle
                    .padding(.bottom, Spacing.l)

                Divider()
                    .overlay(Theme.separator)
                    .padding(.bottom, Spacing.l)

                actions
            }
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.xxl)
        }
        .background(Theme.cardBackground)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Subviews

    private var grabHandle: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Theme.separator)
            .frame(width: 36, height: 4)
            .frame(maxWidth: .infinity)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.l)
            .accessibilityHidden(true)
    }

    private var eyebrow: some View {
        Text("Squirl + Calendar")
            .font(Typography.label)
            .textCase(.uppercase)
            .foregroundStyle(Theme.accent)
            .tracking(1)
            .padding(.bottom, Spacing.s)
    }

    private var infoRows: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            infoRow(
                icon: "calendar",
                iconColor: Theme.accent,
                headline: "Event titles, times, and counts",
                detail: "Squirl reads your calendar to show a one-line summary beside each check-in: what meetings you had, what else was on."
            )
            infoRow(
                icon: "lock.fill",
                iconColor: Theme.meadowGreen,
                headline: "Stays on this device",
                detail: "Nothing from your calendar ever leaves your iPhone. No server, no sync, no sharing."
            )
            infoRow(
                icon: "brain",
                iconColor: Palette.medication,
                headline: "Your memory, extended",
                detail: "See what your day held beside each check-in, so months-old entries tell the full story."
            )
        }
    }

    private func infoRow(icon: String, iconColor: Color, headline: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.surface2)
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(headline)
                    .font(Typography.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var titlesToggle: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Capture event titles")
                    .font(Typography.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text("See event names in day summaries, not just counts. You can change this anytime in Settings.")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("Capture event titles", isOn: $titlesIncluded)
                .labelsHidden()
                .tint(Theme.meadowGreen)
        }
        .padding(Spacing.m)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12))
    }

    private var actions: some View {
        VStack(spacing: Spacing.xs) {
            Button {
                Task {
                    let state = await services.calendarContextService.requestFullAccess()
                    if state == .fullAccess { await services.calendarCoordinator.sweep() }
                    onFinished()
                    dismiss()
                }
            } label: {
                Text("Connect calendar")
                    .font(Typography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.l)
            }
            .background(Theme.meadowGradient, in: Capsule())

            Button {
                UserDefaults.standard.set(true, forKey: CalendarPreferences.Keys.calendarExplainerDeclined)
                onFinished()
                dismiss()
            } label: {
                Text("Not now")
                    .font(Typography.callout)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.m)
            }

            Text("The Calendar row in Settings keeps this option open whenever you're ready.")
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.xs)
        }
    }
}

#Preview {
    Color.gray.opacity(0.3)
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            CalendarExplainerSheet(onFinished: {})
                .withPreviewEnvironment()
        }
        .withPreviewEnvironment()
}
