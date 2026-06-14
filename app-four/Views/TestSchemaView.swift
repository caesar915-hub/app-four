import SwiftUI
import SwiftData

/// A temporary view to verify the SwiftData schema and preview container.
struct TestSchemaView: View {
    @Query(sort: \Recording.createdAt, order: .reverse) 
    private var recordings: [Recording]
    
    var body: some View {
        NavigationStack {
            List(recordings) { recording in
                VStack(alignment: .leading, spacing: 4) {
                    Text(recording.title)
                        .font(.headline)
                    Text("Status: \(recording.status.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Duration: \(recording.formattedDuration)")
                        .font(.caption2)
                    
                    if !recording.fullTranscriptText.isEmpty {
                        Text(recording.fullTranscriptText)
                            .font(.body)
                            .lineLimit(1)
                            .padding(.top, 4)
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Schema Test")
        }
    }
}

#Preview {
    TestSchemaView()
        .modelContainer(AppModelContainer.previewContainer)
}
