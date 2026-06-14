import SwiftUI

struct SettingsWireframe: View {
    var body: some View {
        VStack(spacing: 0) {
            MedicationBarWireframe()
                .padding(.top)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    sectionHeader("AI Models")
                    VStack {
                        settingRow(icon: "waveform", color: .blue, title: "Whisper Transcription", value: "Installed", valueColor: .green)
                    }
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    sectionHeader("System")
                    VStack(spacing: 0) {
                        settingRow(icon: "", color: .clear, title: "Storage", value: "11 recordings · 0.1 MB", valueColor: .gray)
                        Divider().padding(.leading, 16)
                        toggleRow(icon: "antenna.radiowaves.left.and.right", color: .blue, title: "Download over Cellular", isOn: false)
                    }
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    sectionHeader("Medication Bar")
                    VStack(spacing: 0) {
                        toggleRow(icon: "pills.circle.fill", color: .blue, title: "Show Medication Bar", isOn: true)
                        Divider().padding(.leading, 16)
                        toggleRow(icon: "pill", color: .blue, title: "Show Medication Name", isOn: true)
                        Divider().padding(.leading, 16)
                        toggleRow(icon: "clock", color: .blue, title: "Show Taken Time", isOn: true)
                        Divider().padding(.leading, 16)
                        toggleRow(icon: "clock.arrow.circlepath", color: .blue, title: "Show End Time", isOn: true)
                    }
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    sectionHeader("Accessibility")
                    VStack {
                        toggleRow(icon: "link", color: .blue, title: "Medical Context Prompt", isOn: false)
                    }
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .padding()
                .padding(.bottom, 80)
            }
            
            TabBarWireframe(selected: "Settings")
        }
        .overlay(alignment: .bottomTrailing) {
            FloatingChatButton()
                .padding(.bottom, 120)
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .foregroundColor(.gray)
            .padding(.leading, 8)
            .padding(.bottom, -16)
    }
    
    private func settingRow(icon: String, color: Color, title: String, value: String, valueColor: Color) -> some View {
        HStack {
            if !icon.isEmpty {
                Image(systemName: icon).foregroundColor(color).frame(width: 24)
            }
            Text(title)
            Spacer()
            if valueColor == .green {
                Circle().fill(Color.green).frame(width: 8, height: 8)
            }
            Text(value).foregroundColor(valueColor)
        }
        .padding()
    }
    
    private func toggleRow(icon: String, color: Color, title: String, isOn: Bool) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(color).frame(width: 24)
            Text(title)
            Spacer()
            Toggle("", isOn: .constant(isOn)).labelsHidden()
        }
        .padding()
    }
}

#Preview { SettingsWireframe() }
