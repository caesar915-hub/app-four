import SwiftUI
import SwiftData

struct TestServicesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(RecordingStore.self) private var store
    @AppStorage("debugMockMode") private var mockMode: Bool = false
    @Query(sort: \Recording.createdAt, order: .reverse) private var recordings: [Recording]

    @State private var storageService: AudioFileStorageServiceImpl?
    @State private var audioService = AudioRecordingServiceImpl()
    @State private var aiModelService = AIModelServiceImpl(context: AppModelContainer.container.mainContext)

    @State private var isRecording = false
    @State private var lastError: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Filesystem & Storage") {
                    Button("Test Disk Check") {
                        Task {
                            if let storage = getStorage() {
                                let free = await storage.availableStorage()
                                AppLogger.log("Available: \(free / 1_048_576) MB")
                            }
                        }
                    }

                    Button("Create Fake Recording") {
                        Task {
                            if let storage = getStorage() {
                                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("fake.m4a")
                                try? "fake audio".data(using: .utf8)?.write(to: tempURL)
                                _ = try? storage.saveRecording(from: tempURL, duration: 10)
                            }
                        }
                    }

                    Button("Calculate Total Storage") {
                        Task {
                            if let storage = getStorage() {
                                let used = await storage.calculateTotalStorageUsed()
                                AppLogger.log("Total Storage Used: \(used) bytes")
                            }
                        }
                    }
                }

                Section("Metadata & List") {
                    Text("Total Recordings: \(recordings.count)")

                    ForEach(recordings) { recording in
                        VStack(alignment: .leading) {
                            Text(recording.title)
                                .font(.headline)
                            Text(recording.audioFileName)
                                .font(.caption)
                        }
                    }
                }

                Section("Mock Data") {
                    Toggle("Mock Mode", isOn: $mockMode)
                        .onChange(of: mockMode) {
                            store.loadRecordings()
                            NotificationCenter.default.post(name: .medicationEventsDidChange, object: nil)
                        }

                    let hasMock = recordings.contains { $0.isMockData }

                    Button("Seed Mock Data") {
                        MockDataGenerator.generate(context: modelContext)
                        store.loadRecordings()
                        NotificationCenter.default.post(name: .medicationEventsDidChange, object: nil)
                        NotificationCenter.default.post(name: .nutritionEventsDidChange, object: nil)
                    }
                    .disabled(hasMock)

                    Button("Wipe & Reseed", role: .destructive) {
                        let mockRecordings = recordings.filter { $0.isMockData }
                        for rec in mockRecordings { modelContext.delete(rec) }
                        let mockEvents = (try? modelContext.fetch(FetchDescriptor<MedicationEvent>()))?.filter { $0.isMockData } ?? []
                        for event in mockEvents { modelContext.delete(event) }
                        try? modelContext.save()
                        MockDataGenerator.generate(context: modelContext)   // re-seeds nutrition too (self-wiping)
                        store.loadRecordings()
                        NotificationCenter.default.post(name: .medicationEventsDidChange, object: nil)
                        NotificationCenter.default.post(name: .nutritionEventsDidChange, object: nil)
                    }
                    .disabled(!hasMock)
                }

                Section("Nutrition demo (spec 031)") {
                    let mockCount = (try? modelContext.fetchCount(FetchDescriptor<NutritionEvent>(
                        predicate: #Predicate { $0.isMockData == true }))) ?? 0
                    let realCount = (try? modelContext.fetchCount(FetchDescriptor<NutritionEvent>(
                        predicate: #Predicate { $0.isMockData == false }))) ?? 0
                    LabeledContent("Events", value: "\(mockCount) mock · \(realCount) real")

                    Button("Reseed 30-Day Nutrition") {
                        MockDataGenerator.seedNutritionEvents(context: modelContext)
                        NotificationCenter.default.post(name: .nutritionEventsDidChange, object: nil)
                    }

                    Button("Wipe Nutrition Data", role: .destructive) {
                        MockDataGenerator.wipeMockNutritionEvents(context: modelContext)
                        NotificationCenter.default.post(name: .nutritionEventsDidChange, object: nil)
                    }
                    .disabled(mockCount == 0)
                }

                Section("Exports & Actions") {
                    Button("Export Last") {
                        Task {
                            if let storage = getStorage(), let last = recordings.first {
                                _ = try? await storage.exportTranscript(last, format: .json)
                            }
                        }
                    }

                    Button("Delete All") {
                        if let storage = getStorage() {
                            for rec in recordings {
                                try? storage.deleteRecording(rec)
                            }
                        }
                    }
                }

                Section("Audio & AI Models") {
                    Button("Test Whisper Status") {
                        Task {
                            let status = await aiModelService.status(for: .whisper)
                            AppLogger.log("Whisper Status: \(String(describing: status))")
                        }
                    }

                    if !isRecording {
                        Button("Start Real Recording") {
                            Task {
                                do {
                                    _ = try await audioService.startRecording()
                                    isRecording = true
                                } catch {
                                    lastError = error.localizedDescription
                                }
                            }
                        }
                    } else {
                        Button("Stop Recording", role: .destructive) {
                            Task {
                                do {
                                    let result = try await audioService.stopRecording()
                                    isRecording = false
                                    if let storage = getStorage() {
                                        _ = try storage.saveRecording(from: result.fileURL, duration: result.duration)
                                    }
                                } catch {
                                    lastError = error.localizedDescription
                                }
                            }
                        }
                    }
                }

                if let error = lastError {
                    Section("Error") {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Service Debug")
            .toolbar {
                Button("Done") {
                    // Close sheet action would go here
                }
            }
        }
    }

    private func getStorage() -> AudioFileStorageServiceImpl? {
        if storageService == nil {
            storageService = AudioFileStorageServiceImpl(context: modelContext)
        }
        return storageService
    }
}

#Preview {
    TestServicesView()
        .modelContainer(AppModelContainer.previewContainer)
}
