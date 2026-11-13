//
//  CaptureView.swift
//  Apexiel Proj1
//
//  Created by Kenji Fahselt on 2/18/26.
//

import SwiftUI
import CoreLocation

struct CaptureView: View {
    @StateObject private var vm = DrivingLogicViewModel()
    
    // UI Presentation State
    @State private var showVault = false
    @State private var showHeatSheet: Bool = false
    
    // NEW: State for the save confirmation popup
    @State private var showSaveToast: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background Color (Dark for racing vibes)
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    
                    // ------------------------------------------------
                    // 1. BIG SPEEDOMETER (Driver View)
                    // ------------------------------------------------
                    VStack(spacing: 0) {
                        Text("\(Int(vm.currentSpeed))")
                            .font(.system(size: 120, weight: .black, design: .rounded))
                            .foregroundStyle(vm.isRecording ? .green : .primary)
                            // Numeric transition animation
                            .contentTransition(.numericText(value: vm.currentSpeed))
                        
                        Text("MPH")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)
                    
                    Spacer()
                    
                    // ------------------------------------------------
                    // 2. DEV FEEDBACK CONSOLE
                    // ------------------------------------------------
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("DEV TELEMETRY MONITOR")
                                .font(.caption).bold()
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                showVault = true
                            } label: {
                                Image(systemName: "server.rack")
                                    .font(.title3)
                                    .foregroundStyle(.white)
                                    .padding(8)
                                    .background(Color(white: 0.25))
                                    .clipShape(Circle())
                            }
                        }
                        
                        Divider()
                        
                        Group {
                            DebugRow(label: "Status", value: vm.isRecording ? "REC ●" : "IDLE", color: vm.isRecording ? .red : .gray)
                            DebugRow(label: "Points Captured", value: "\(vm.pointCount)")
                            if let loc = vm.previousLocation {
                                DebugRow(label: "Lat/Lon", value: String(format: "%.5f, %.5f", loc.coordinate.latitude, loc.coordinate.longitude))
                                DebugRow(label: "Alt / Acc", value: String(format: "%.1fm / ±%.1fm", loc.altitude, loc.horizontalAccuracy))
                            } else {
                                DebugRow(label: "GPS", value: "Waiting for fix...")
                            }
                            
                            if vm.isRecording, let url = vm.sessionManager.currentFileURL {
                                DebugRow(label: "File", value: url.lastPathComponent, truncate: true)
                            }
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // ------------------------------------------------
                    // 3. START / STOP BUTTON
                    // ------------------------------------------------
                    Button {
                        // Haptic Feedback
                        let impact = UIImpactFeedbackGenerator(style: .heavy)
                        impact.impactOccurred()
                        vm.toggleSession()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(vm.isRecording ? .red : .green)
                                .frame(width: 80, height: 80)
                                .shadow(radius: 10)
                            
                            Image(systemName: vm.isRecording ? "stop.fill" : "play.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.bottom, 20)
                    
                    // ------------------------------------------------
                    // 4. THE HEAT SELECTOR BUTTON
                    // ------------------------------------------------
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showHeatSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "flag.checkered")
                            Text(vm.selectedHeat)
                                .fontWeight(.bold)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                        }
                        .padding()
                        .background(Color(white: 0.15))
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
                
                // ------------------------------------------------
                // 5. TRANSIENT "LAP SAVED" TOAST POPUP
                // ------------------------------------------------
                if showSaveToast {
                    VStack {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.green)
                            Text("Lap Saved Successfully")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Color(white: 0.15))
                        .cornerRadius(30)
                        .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 30)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        // Slide down from the top
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 20)
                        
                        Spacer()
                    }
                    .zIndex(1) // Ensure it floats above the UI
                }
            }
            .navigationTitle("Data Capture")
            .navigationBarTitleDisplayMode(.inline)
            
            // MARK: - MODALS & LOGIC
            .sheet(isPresented: $showVault) {
                SessionHistorySheet()
                    .presentationDetents([.fraction(0.8), .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showHeatSheet) {
                HeatSelectionSheet(
                    availableHeats: $vm.availableHeats,
                    selectedHeat: $vm.selectedHeat
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            
            // NEW: Just trigger the popup instead of loading heavy data and switching screens
            .onChange(of: vm.sessionSavedURL) { newURL in
                if newURL != nil {
                    // 1. Show the Toast
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        showSaveToast = true
                    }
                    
                    // 2. Hide it automatically after 2.5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showSaveToast = false
                        }
                    }
                }
            }
        }
    }
}


// MARK: - HEAT SELECTION SHEET
struct HeatSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var availableHeats: [String]
    @Binding var selectedHeat: String
    
    @State private var newHeatName: String = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack {
                        TextField("New Heat Name...", text: $newHeatName)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.done)
                            .onSubmit { addHeat() }
                        
                        Button {
                            addHeat()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(newHeatName.isEmpty ? .gray : .red)
                        }
                        .disabled(newHeatName.isEmpty)
                    }
                    .padding()
                    .background(Color(white: 0.1))
                    
                    List {
                        ForEach(availableHeats, id: \.self) { heat in
                            Button {
                                selectedHeat = heat
                                dismiss()
                            } label: {
                                HStack {
                                    Text(heat)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    if heat == selectedHeat {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.red)
                                    }
                                }
                            }
                            .listRowBackground(Color(white: 0.15))
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Select Heat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
    
    private func addHeat() {
        let cleanName = newHeatName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanName.isEmpty && !availableHeats.contains(cleanName) {
            availableHeats.insert(cleanName, at: 0)
            selectedHeat = cleanName
            dismiss()
        }
    }
}

// MARK: - SESSION HISTORY SHEET (Vault)
struct SessionHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sessionFiles: [URL] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                
                if sessionFiles.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 48))
                            .foregroundStyle(.gray)
                        Text("No telemetry data found.")
                            .font(.headline)
                            .foregroundStyle(.gray)
                    }
                } else {
                    List {
                        ForEach(sessionFiles, id: \.self) { url in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(url.lastPathComponent)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    
                                    Text(getFileSize(url: url))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.gray)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.gray.opacity(0.5))
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(Color(white: 0.15))
                        }
                        .onDelete(perform: deleteFiles)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Telemetry Vault")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(.red)
                }
            }
            .onAppear(perform: loadFiles)
        }
        .preferredColorScheme(.dark)
    }
    
    private func loadFiles() {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        do {
            let files = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            self.sessionFiles = files
                .filter { $0.pathExtension == "jsonl" }
                .sorted { url1, url2 in
                    let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    return date1 > date2
                }
        } catch {
            print("❌ Error loading files: \(error.localizedDescription)")
        }
    }
    
    private func deleteFiles(at offsets: IndexSet) {
        let fileManager = FileManager.default
        for index in offsets {
            let url = sessionFiles[index]
            do {
                try fileManager.removeItem(at: url)
                sessionFiles.remove(at: index)
            } catch {
                print("❌ Failed to delete file: \(error.localizedDescription)")
            }
        }
    }
    
    private func getFileSize(url: URL) -> String {
        do {
            let resources = try url.resourceValues(forKeys: [.fileSizeKey])
            if let fileSize = resources.fileSize {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useKB, .useMB]
                formatter.countStyle = .file
                return formatter.string(fromByteCount: Int64(fileSize))
            }
        } catch {
            return "Unknown Size"
        }
        return "Unknown Size"
    }
}

// MARK: - Helper View for Dev Stats
struct DebugRow: View {
    let label: String
    let value: String
    var color: Color = .primary
    var truncate: Bool = false
    
    var body: some View {
        HStack {
            Text(label + ":")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospaced())
                .bold()
                .foregroundStyle(color)
                .lineLimit(truncate ? 1 : nil)
                .truncationMode(.middle)
        }
    }
}

#Preview {
    CaptureView()
}
