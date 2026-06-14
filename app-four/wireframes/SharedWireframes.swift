import SwiftUI

/// Shared components that appear across multiple wireframe screens.
struct MedicationBarWireframe: View {
    var body: some View {
        VStack(spacing: 8) {
            medRow(label: "1st dose · Concerta 36mg · 12:23", end: "ends 22:23", progressWidth: 80)
            medRow(label: "2nd dose · Concerta 36mg · 13:22", end: "ends 23:22", progressWidth: 40)
        }
        .padding(.horizontal)
    }
    
    private func medRow(label: String, end: String, progressWidth: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.1))
            
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.4))
                .frame(width: progressWidth)
            
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
            
            HStack {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                Spacer()
                Text(end)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 44)
    }
}

struct TabBarWireframe: View {
    var selected: String
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                tabItem(icon: "calendar", title: "Calendar", isSelected: selected == "Calendar")
                Spacer()
                tabItem(icon: "waveform", title: "Check in", isSelected: selected == "Check in", isBlue: selected == "Check in")
                Spacer()
                tabItem(icon: "chart.bar.fill", title: "Insights", isSelected: selected == "Insights")
                Spacer()
                tabItem(icon: "gearshape", title: "Settings", isSelected: selected == "Settings")
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 24) // safe area spacing
            .background(Color(.systemBackground))
        }
    }
    
    private func tabItem(icon: String, title: String, isSelected: Bool, isBlue: Bool = false) -> some View {
        VStack(spacing: 4) {
            ZStack {
                if isSelected {
                    Capsule()
                        .fill(isBlue ? Color.blue.opacity(0.15) : Color.blue.opacity(0.15))
                        .frame(width: 56, height: 32)
                }
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            Text(title)
                .font(.caption2)
                .foregroundColor(isSelected ? .blue : .gray)
        }
        .frame(width: 60)
    }
}

struct FloatingChatButton: View {
    var body: some View {
        Button(action: {}) {
            Image(systemName: "exclamationmark.bubble.fill")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 50, height: 50)
                .background(Color(.systemBackground))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .padding()
    }
}
