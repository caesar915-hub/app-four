import SwiftUI

struct InsightsWireframe: View {
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
                VStack(spacing: 24) {
                    // Chart Card
                    VStack {
                        Circle()
                            .strokeBorder(Color.blue.opacity(0.8), lineWidth: 30) // Simplified doughnut chart placeholder
                            .frame(width: 200, height: 200)
                            .padding()
                        
                        HStack(spacing: 16) {
                            legendItem(color: .teal, icon: "smiley.fill", title: "Great")
                            legendItem(color: .green, icon: "face.smiling", title: "Good")
                            legendItem(color: .blue, icon: "face.dashed", title: "Neutral")
                            legendItem(color: .orange, icon: "bolt.fill", title: "Low")
                            legendItem(color: .red, icon: "cloud.rain.fill", title: "Rough")
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    VStack(spacing: 4) {
                        Text("Your overall check-in breakdown").font(.headline)
                        Text("11 check-ins this month · mostly neutral").font(.subheadline).foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("Your mood during the day").font(.title3).bold()
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    HStack(alignment: .bottom, spacing: 8) {
                        RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.3)).frame(height: 80)
                        RoundedRectangle(cornerRadius: 8).fill(Color.gray).frame(height: 120)
                        RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.3)).frame(height: 60)
                        RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.3)).frame(height: 100)
                    }
                    .padding(.horizontal)
                    .frame(height: 150)
                }
                .padding(.bottom, 80)
            }
            
            Spacer(minLength: 0)
            TabBarWireframe(selected: "Insights")
        }
        .overlay(alignment: .bottomTrailing) {
            FloatingChatButton()
                .padding(.bottom, 180)
        }
    }
    
    private func legendItem(color: Color, icon: String, title: String) -> some View {
        VStack(spacing: 4) {
            Circle().fill(color).frame(width: 40, height: 40)
                .overlay(Image(systemName: icon).foregroundColor(.white))
            Text(title).font(.caption)
        }
    }
}

#Preview { InsightsWireframe() }
