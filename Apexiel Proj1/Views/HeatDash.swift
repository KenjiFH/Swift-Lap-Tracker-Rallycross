//
//  HeatDash.swift
//  Apexiel Proj1
//
//  Created by Kenji Fahselt on 3/3/26.
//

import SwiftUI
import FirebaseFirestore // NEW: Added for cloud sync checks

// MARK: - 1. DATA MODELS (Refactored for Sync Status)

/// Represents a single physical `.jsonl` file on disk and its cloud status.
struct SessionLap: Identifiable, Hashable {
    let id = UUID()
    let fileURL: URL
    var isSynced: Bool
}

/// Represents a collection of laps grouped by the "Heat Name" prefix.
struct HeatGroup: Identifiable, Hashable {
    let id = UUID()
    let heatName: String
    var laps: [SessionLap] // CHANGED: Replaced [URL] with [SessionLap]
    let date: Date
}


// MARK: - 2. THE VIEW MODEL (The New Brain)
@MainActor
class HeatDashboardViewModel: ObservableObject {
    @Published var heatGroups: [HeatGroup] = []
    @Published var isParsing = false
    @Published var navigateToSummary = false
    @Published var selectedParsedLaps: [[DrivingTelemDataPoint]]? = nil
    
    private let db = Firestore.firestore()
    
    // MARK: The Hybrid Loader (Local + Cloud Merge)
    func loadHeatsFromDisk() {
        // 1. INSTANT LOCAL LOAD (Offline First)
        let fileManager = FileManager.default
        guard let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        do {
            let files = try fileManager.contentsOfDirectory(at: docsURL, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            let jsonlFiles = files.filter { $0.pathExtension == "jsonl" }
            
            var groupedDict: [String: [URL]] = [:]
            for file in jsonlFiles {
                let filename = file.lastPathComponent
                let heatPrefix = filename.components(separatedBy: "_").first?.replacingOccurrences(of: "-", with: " ") ?? "Unknown Heat"
                groupedDict[heatPrefix, default: []].append(file)
            }
            
            // Build the initial UI state (Defaulting to NOT synced)
            var initialGroups: [HeatGroup] = groupedDict.map { key, urls in
                let sortedURLs = urls.sorted { u1, u2 in
                    let d1 = (try? u1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    let d2 = (try? u2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    return d1 < d2
                }
                let groupDate = (try? sortedURLs.first?.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date()
                
                // Wrap raw URLs into the new SessionLap struct
                let sessionLaps = sortedURLs.map { SessionLap(fileURL: $0, isSynced: false) }
                
                return HeatGroup(heatName: key, laps: sessionLaps, date: groupDate)
            }.sorted { $0.date > $1.date }
            
            // Push to UI immediately so the user doesn't wait
            self.heatGroups = initialGroups
            
            // ---------------------------------------------------------
            // 🔥 2. BACKGROUND CLOUD MERGE
            // ---------------------------------------------------------
            Task {
                do {
                    // Ask Firestore what files it has successfully ingested
                    let snapshot = try await db.collection("sessions").getDocuments()
                    
                    // Create a fast lookup Set (O(1) complexity)
                    let syncedFileNames = Set(snapshot.documents.compactMap { $0.data()["fileName"] as? String })
                    
                    // If we found cloud files, update our local array
                    if !syncedFileNames.isEmpty {
                        for i in 0..<initialGroups.count {
                            for j in 0..<initialGroups[i].laps.count {
                                let localName = initialGroups[i].laps[j].fileURL.lastPathComponent
                                if syncedFileNames.contains(localName) {
                                    initialGroups[i].laps[j].isSynced = true
                                }
                            }
                        }
                        
                        // Overwrite the Published array to trigger a SwiftUI redraw with the Green Checkmarks
                        self.heatGroups = initialGroups
                    }
                } catch {
                    print("⚠️ Cloud sync check failed. Continuing in offline mode. (\(error.localizedDescription))")
                }
            }
            
        } catch {
            print("❌ Failed to load local heats: \(error)")
        }
    }
    
    // MARK: Parse and Route
    func processAndNavigate(group: HeatGroup) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        self.isParsing = true
        
        Task(priority: .userInitiated) {
            var compiledLaps: [[DrivingTelemDataPoint]] = []
            
            // The laps are already sorted chronologically from loadHeatsFromDisk
            for lap in group.laps {
                let singleLapArray = SessionParser.loadLapData(from: lap.fileURL)
                if !singleLapArray.isEmpty {
                    compiledLaps.append(singleLapArray)
                }
            }
            
            await MainActor.run {
                self.selectedParsedLaps = compiledLaps
                self.isParsing = false
                self.navigateToSummary = true
            }
        }
    }
}


// MARK: - 3. MAIN VIEW (Clean & Declarative)
struct HeatDashboardView: View {
    @StateObject private var viewModel = HeatDashboardViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                if viewModel.heatGroups.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "flag.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(.gray)
                        Text("No heats recorded yet.")
                            .font(.headline)
                            .foregroundStyle(.gray)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(viewModel.heatGroups) { group in
                                HeatCard(group: group)
                                    .onTapGesture {
                                        viewModel.processAndNavigate(group: group)
                                    }
                            }
                        }
                        .padding()
                    }
                    // NEW: Pull to refresh allows manual sync checking
                    .refreshable {
                        viewModel.loadHeatsFromDisk()
                    }
                }
                
                // Loading Overlay
                if viewModel.isParsing {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    ProgressView("Parsing Telemetry...")
                        .padding()
                        .background(Color(white: 0.15))
                        .cornerRadius(12)
                        .foregroundStyle(.white)
                }
            }
            .navigationTitle("Your Heats")
            .onAppear {
                viewModel.loadHeatsFromDisk()
            }
            // THE HANDOFF
            .navigationDestination(isPresented: $viewModel.navigateToSummary) {
                if let laps = viewModel.selectedParsedLaps {
                    SessionSummaryView(laps: laps)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - 4. VERTICAL CARD UI
struct HeatCard: View {
    let group: HeatGroup
    
    // Helper to calculate how many laps successfully made it to the cloud
    var syncCount: Int {
        group.laps.filter { $0.isSynced }.count
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(group.heatName)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                        Text(group.date.formatted(date: .abbreviated, time: .shortened))
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "flag.checkered")
                        Text("\(group.laps.count) Laps")
                    }
                    
                    // NEW: Sync Status Indicator
                    HStack(spacing: 4) {
                        if syncCount == group.laps.count {
                            // All laps synced
                            Image(systemName: "checkmark.icloud.fill")
                                .foregroundStyle(.green)
                        } else if syncCount > 0 {
                            // Partial sync (e.g. 1 out of 3 uploaded)
                            Image(systemName: "arrow.triangle.2.circlepath.icloud")
                                .foregroundStyle(.orange)
                        } else {
                            // Local only
                            Image(systemName: "icloud.slash")
                                .foregroundStyle(.gray)
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.gray)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.gray.opacity(0.5))
        }
        .padding()
        .background(Color(white: 0.15))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
    }
}

// Keep your existing preview macro exactly as it was
#Preview {
    HeatDashboardView()
}
