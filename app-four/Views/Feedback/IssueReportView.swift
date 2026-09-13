#if DEBUG || TESTFLIGHT
import SwiftUI
import MessageUI

/// Form sheet for collecting beta feedback. All sensitive data toggles default to OFF.
/// The report is sent via the user's Mail app (or share sheet fallback).
struct IssueReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ScreenTracker.self) private var screenTracker
    @Environment(\.diagnosticsStore) private var diagnosticsStore

    // User input
    @State private var userDescription = ""

    // Sensitive data toggles — ALL default OFF
    @State private var includeTranscription = false
    @State private var includeSummary = false
    @State private var includeAudio = false
    @State private var includeLogs = true

    // Async-loaded state
    @State private var recentSnapshots: [SessionSnapshot] = []
    @State private var screenshot: UIImage?

    // Presentation
    @State private var isShowingMailComposer = false
    @State private var isShowingShareSheet = false
    @State private var shareItems: [Any] = []

    // System context
    private let deviceModel = UIDevice.current.model
    private let iOSVersion = UIDevice.current.systemVersion
    private let appBuild = SessionSnapshot.currentAppBuild()

    var body: some View {
        NavigationStack {
            Form {
                descriptionSection
                contextSection
                sensitiveDataSection
                logsSection
            }
            .navigationTitle("Report Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { prepareAndSend() }
                        .disabled(userDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .task {
                await loadDiagnostics()
            }
            .sheet(isPresented: $isShowingMailComposer) {
                MailComposeView(
                    recipient: "caesar915@icloud.com",
                    subject: "Squirl Beta Feedback — Build \(appBuild)",
                    body: composedBody,
                    attachments: reportAttachments
                ) { result in
                    handleMailResult(result)
                }
            }
            .sheet(isPresented: $isShowingShareSheet) {
                ShareSheetView(items: shareItems)
            }
        }
    }

    // MARK: - Sections

    private var descriptionSection: some View {
        Section("What went wrong?") {
            TextEditor(text: $userDescription)
                .frame(minHeight: 120)
        }
    }

    private var contextSection: some View {
        Section("Auto-captured context") {
            LabeledContent("Screen", value: screenTracker.currentScreen)
            LabeledContent("App Build", value: appBuild)
            LabeledContent("Device", value: deviceModel)
            LabeledContent("iOS", value: iOSVersion)

            if let lastSnapshot = recentSnapshots.first {
                LabeledContent("Thermal", value: lastSnapshot.thermalState)
                LabeledContent("Available RAM", value: "\(lastSnapshot.availableMemoryMB) MB")
                if lastSnapshot.whisperDurationMs > 0 {
                    LabeledContent("Last Whisper", value: "\(String(format: "%.0f", lastSnapshot.whisperDurationMs)) ms")
                }
            }
        }
    }

    private var sensitiveDataSection: some View {
        Section("Include Sensitive Data?") {
            Toggle("Include Transcription Text", isOn: $includeTranscription)
            Toggle("Include Summary Text", isOn: $includeSummary)
            Toggle("Include Audio File", isOn: $includeAudio)

            if includeTranscription {
                DisclosureGroup("Transcription preview") {
                    Text("Transcription content will be attached as transcription.txt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if includeSummary {
                DisclosureGroup("Summary preview") {
                    Text("Summary content will be attached as summary.txt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if includeAudio {
                DisclosureGroup("Audio preview") {
                    Text("Audio file will be attached as audio.m4a")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var logsSection: some View {
        Section("Diagnostics") {
            Toggle("Include Recent Logs", isOn: $includeLogs)
        }
    }

    // MARK: - Data Loading

    private func loadDiagnostics() async {
        recentSnapshots = await diagnosticsStore.recentSnapshots(limit: 5)
        let capture = ScreenshotCapture()
        screenshot = await capture.capture()
    }

    // MARK: - Report Composition

    private var composedBody: String {
        var lines: [String] = []
        lines.append("--- User Description ---")
        lines.append(userDescription)
        lines.append("")
        lines.append("--- System Context ---")
        lines.append("Screen: \(screenTracker.currentScreen)")
        lines.append("Build: \(appBuild)")
        lines.append("Device: \(deviceModel)")
        lines.append("iOS: \(iOSVersion)")

        if let snapshot = recentSnapshots.first {
            lines.append("Thermal: \(snapshot.thermalState)")
            lines.append("Available RAM: \(snapshot.availableMemoryMB) MB")
            if snapshot.whisperDurationMs > 0 {
                lines.append("Last Whisper: \(String(format: "%.0f", snapshot.whisperDurationMs)) ms")
            }
        }

        lines.append("")
        lines.append("--- Attachments ---")
        var attachments: [String] = []
        attachments.append("screenshot.png")
        if includeLogs { attachments.append("sessions.json") }
        if includeTranscription { attachments.append("transcription.txt") }
        if includeSummary { attachments.append("summary.txt") }
        if includeAudio { attachments.append("audio.m4a") }
        lines.append(attachments.joined(separator: ", "))

        return lines.joined(separator: "\n")
    }

    private var reportAttachments: [MailAttachment] {
        var attachments: [MailAttachment] = []

        // Screenshot
        if let image = screenshot, let data = image.pngData() {
            attachments.append(MailAttachment(data: data, mimeType: "image/png", fileName: "screenshot.png"))
        }

        // Logs
        if includeLogs {
            let archive = SessionSnapshotArchive(snapshots: recentSnapshots)
            if let data = try? JSONEncoder().encode(archive) {
                attachments.append(MailAttachment(data: data, mimeType: "application/json", fileName: "sessions.json"))
            }
        }

        // Placeholder attachments for sensitive data (real app would fill these from current recording)
        if includeTranscription {
            attachments.append(MailAttachment(
                data: "[Transcription text would be inserted from current recording]".data(using: .utf8) ?? Data(),
                mimeType: "text/plain",
                fileName: "transcription.txt"
            ))
        }
        if includeSummary {
            attachments.append(MailAttachment(
                data: "[Summary text would be inserted from current recording]".data(using: .utf8) ?? Data(),
                mimeType: "text/plain",
                fileName: "summary.txt"
            ))
        }
        if includeAudio {
            attachments.append(MailAttachment(
                data: Data(),
                mimeType: "audio/m4a",
                fileName: "audio.m4a"
            ))
        }

        return attachments
    }

    // MARK: - Sending

    private func prepareAndSend() {
        if MFMailComposeViewController.canSendMail() {
            isShowingMailComposer = true
        } else {
            var items: [Any] = [composedBody]
            if let image = screenshot {
                items.append(image)
            }
            shareItems = items
            isShowingShareSheet = true
        }
    }

    private func handleMailResult(_ result: MFMailComposeResult) {
        switch result {
        case .sent:
            dismiss()
        case .saved, .cancelled:
            break
        case .failed:
            var items: [Any] = [composedBody]
            if let image = screenshot {
                items.append(image)
            }
            shareItems = items
            isShowingShareSheet = true
        @unknown default:
            break
        }
    }
}

// MARK: - Supporting Types

struct MailAttachment {
    let data: Data
    let mimeType: String
    let fileName: String
}
#endif
