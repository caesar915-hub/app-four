import SwiftUI

struct DetailWireframe: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .padding()
                Spacer()
            }
            
            MedicationBarWireframe()
            
            ScrollView {
                VStack(spacing: 16) {
                    // Header Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Circle().fill(Color.gray).frame(width: 48, height: 48)
                            Text("Alert").font(.title2).fontWeight(.bold)
                            Spacer()
                            Image(systemName: "pencil").foregroundColor(.blue)
                        }
                        Text("9 June 2026 13:22 · 0:00")
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    
                    // Log Entries
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Log Entries").font(.headline)
                            Spacer()
                            Image(systemName: "arrow.triangle.2.circlepath").foregroundColor(.blue)
                        }
                        
                        VStack(spacing: 4) {
                            Text("⚡️ Energy").font(.caption).foregroundColor(.orange)
                            Text("Alert").font(.subheadline).fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Medication").font(.caption).foregroundColor(.gray)
                                HStack {
                                    Image(systemName: "pills.fill").foregroundColor(.purple)
                                    Text("13:22  Concerta 36mg").fontWeight(.medium)
                                }
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    
                    // Transcript
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Transcript").font(.headline)
                            Spacer()
                            Text("Completed")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.15))
                                .cornerRadius(8)
                            Image(systemName: "chevron.down").foregroundColor(.gray)
                        }
                        
                        HStack {
                            Image(systemName: "play.circle.fill").font(.largeTitle).foregroundColor(.gray)
                            Spacer()
                            ForEach(0..<20) { _ in
                                Capsule().fill(Color.gray.opacity(0.3)).frame(width: 3, height: 20)
                            }
                            Spacer()
                            Text("00:00").font(.caption).monospacedDigit()
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                }
                .padding()
            }
            
            TabBarWireframe(selected: "Calendar")
        }
        .overlay(alignment: .bottomTrailing) {
            FloatingChatButton()
                .padding(.bottom, 150)
        }
    }
}

#Preview { DetailWireframe() }
