import SwiftUI

struct CalendarWireframe: View {
    var body: some View {
        VStack(spacing: 0) {
            MedicationBarWireframe()
                .padding(.top)
            
            // Month Selector
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("JUN 2026")
                        .font(.headline)
                        .fontWeight(.bold)
                    Rectangle()
                        .fill(Color.primary)
                        .frame(width: 80, height: 2)
                }
                Spacer()
            }
            .padding()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Date Header
                    HStack(spacing: 8) {
                        Circle().fill(Color.gray.opacity(0.5)).frame(width: 8, height: 8)
                        Text("TODAY, 9 JUN")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    
                    // Entries
                    entryCard(color: .gray, title: "Alert", time: "9 Jun at 13:22 · 0:00", tags: [("bolt.fill", "alert energy", Color.orange), ("pills.fill", "Concerta", Color.purple)])
                    
                    entryCard(color: .gray, title: "Flat", time: "9 Jun at 12:23 · 0:00", tags: [("pills.fill", "Concerta", Color.purple)])
                    
                    entryCard(color: .red, title: "Low", time: "9 Jun at 12:23 · 0:00", tags: [])
                    
                    entryCard(color: .gray, title: "Bad mood", time: "9 Jun at 12:23 · 0:00", tags: [])
                    
                    entryCard(color: .yellow, title: "Okay", time: "9 Jun at 12:23 · 0:00", tags: [])
                    
                    entryCard(color: .red, title: "Low", time: "9 Jun at 12:21 · 0:00", tags: [])
                    
                    entryCard(color: .gray, title: "Flat · Alert", time: "9 Jun at 12:21 · 0:00", tags: [("bolt.fill", "alert energy", Color.orange)])
                    
                    entryCard(color: .green, title: "Good · Alert · Sharp", time: "9 Jun at 11:25 · 0:17", tags: [("bolt.fill", "alert energy", Color.orange), ("target", "sharp", Color.indigo)])
                }
                .padding(.bottom, 80)
            }
            
            Spacer(minLength: 0)
            TabBarWireframe(selected: "Calendar")
        }
        .overlay(alignment: .bottomTrailing) {
            FloatingChatButton()
                .padding(.bottom, 80)
        }
    }
    
    private func entryCard(color: Color, title: String, time: String, tags: [(String, String, Color)]) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle().fill(color).frame(width: 12, height: 12).padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title).font(.headline)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                }
                
                Text(time).font(.subheadline).foregroundColor(.gray)
                
                if !tags.isEmpty {
                    HStack {
                        ForEach(tags, id: \.1) { icon, text, tagColor in
                            HStack(spacing: 4) {
                                Image(systemName: icon).font(.caption)
                                Text(text).font(.caption).fontWeight(.medium)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(tagColor.opacity(0.15))
                            .foregroundColor(tagColor)
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
        }
        .padding(.horizontal)
    }
}

#Preview { CalendarWireframe() }
