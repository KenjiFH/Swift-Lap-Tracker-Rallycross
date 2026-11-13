//
//  RaceSessionManager.swift
//  Apexiel Proj1
//

import Foundation


/*
    The RaceSessionManager is the core disk I/O engine for the RX Telemetry application. It operates as a "Black Box" flight recorder, opening our streaming data pipeline directly to the iPhone's physical solid-state drive. It is designed to be strictly Offline-First, ensuring high-frequency sensor data is permanently preserved even in the event of catastrophic application crashes or battery death mid-race.
 */
/// **UPDATE Purpose:**
/// We added actor to prevent race conditions and ensure strict serial access at
/// compile time. Disk I/O operations are queued safely, mathematically guaranteeing the file
/// handle is never mutated concurrently.
actor RaceSessionManager {
    
    var currentFileURL: URL?
    private var fileHandle: FileHandle?
    private let encoder = JSONEncoder()
    
    /// Creates a new `.jsonl` file and opens a streaming file handle
    func startNewSession(heatName: String) -> URL? {
        let fileManager = FileManager.default
        guard let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        
        // 1. Generate a pseudo-ID to prevent cloud collisions if multiple users have this app
        /// multi-tenant backedn was deferred, we descaled to allow multiple drivers to test the app simultaneously without overwriting each other's files in a
        /// communal Cloud Storage bucket, a pseudo-authentication mechanism was implemented. We generate
        /// and cache a permanent UUID in `UserDefaults` (`ApexielDeviceID`) and inject it into the filename,
        let deviceID = UserDefaults.standard.string(forKey: "ApexielDeviceID") ?? {
            let newID = UUID().uuidString
            UserDefaults.standard.set(newID, forKey: "ApexielDeviceID")
            return newID
        }()
        
        // 2. Format the timestamp and clean the heat name
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = formatter.string(from: Date())
        let safeHeatName = heatName.replacingOccurrences(of: " ", with: "-")
        
        // Example: Heat-1_E5A1B2_2026-03-03_14-30-00.jsonl
        let fileName = "\(safeHeatName)_\(deviceID)_\(dateString).jsonl"
        let fileURL = docsURL.appendingPathComponent(fileName)
        
        // 3. Create the empty file
        fileManager.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
        
        // 4. Open the streaming lock
        do {
            self.fileHandle = try FileHandle(forWritingTo: fileURL)
            self.currentFileURL = fileURL
            return fileURL
        } catch {
            print("❌ [RaceSessionManager] Failed to create file handle: \(error)")
            return nil
        }
    }
    
    /// Encodes a point to JSON and safely appends it to the open file
    func recordPoint(_ point: DrivingTelemDataPoint) {
        guard let handle = fileHandle else { return }
        
        do {
            let data = try encoder.encode(point)
            if let jsonString = String(data: data, encoding: .utf8) {
                let line = jsonString + "\n"
                if let lineData = line.data(using: .utf8) {
                    handle.seekToEndOfFile()
                    handle.write(lineData)
                }
            }
        } catch {
            print("⚠️ [RaceSessionManager] Failed to encode/write point: \(error)")
        }
    }
    
    /// Forces the OS to flush the active memory buffer to the SSD, safely closes the file,
        /// and releases the lock so the Cloud Sidecar can upload the completed file.
    func stopSession() -> URL? {
        guard let handle = fileHandle, let url = currentFileURL else { return nil }
        
        do {
            // Force the OS to flush any pending bits in RAM to the physical SSD
            if #available(iOS 13.0, *) {
                try handle.synchronize()
            }
            handle.closeFile()
        } catch {
            print("⚠️ [RaceSessionManager] Failed to close file cleanly: \(error)")
        }
        
        self.fileHandle = nil
        return url
    }
}
    
    /// Helper to list all saved sessions for your "History" screen
     func listSessions() -> [URL] {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let files = (try? FileManager.default.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "jsonl" }.sorted(by: { $0.absoluteString > $1.absoluteString })
    }

