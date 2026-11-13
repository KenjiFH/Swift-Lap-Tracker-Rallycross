//
//  CloudSyncManager.swift
//  Apexiel Proj1
//
//  Created by Kenji Fahselt on 3/14/26.
//


//FIXME fix:
/* error happens whenever you try to upload 
 ❌ [Sidecar] Storage Upload Failed: Object telemetry_blobs/Final_1CAE63E6-8FDA-4648-8C90-5698389C8FC7_2026-04-05_20-55-27.jsonl does not exist.
 */
import Foundation
import FirebaseStorage
import FirebaseFirestore

class CloudSyncManager {
    // Singleton pattern so the whole app can access the same sync queue
    static let shared = CloudSyncManager()
    
    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    
    private init() {}
    
    /// Executes the two-part cloud sync: Blob to Storage, then Metadata to Firestore
    func syncSessionToCloud(localFileURL: URL, heatName: String, totalDistance: Double) {
        let fileName = localFileURL.lastPathComponent
        
        // 1. Define where this file will live in Firebase Storage
        let storageRef = storage.reference().child("telemetry_blobs/\(fileName)")
        
        print("☁️ [Sidecar] Starting upload for \(fileName)...")
        
        // 2. Upload the raw .jsonl file
        storageRef.putFile(from: localFileURL, metadata: nil) { metadata, error in
            if let error = error {
                print("❌ [Sidecar] Storage Upload Failed: \(error.localizedDescription)")
                // Here is where we would normally flag it for a retry later
                return
            }
            
            // 3. If successful, get the cloud download URL
            storageRef.downloadURL { cloudURL, error in
                guard let cloudURL = cloudURL else { return }
                
                print("✅ [Sidecar] Blob uploaded. Writing Metadata to Firestore...")
                
                // 4. Create the Smart Metadata Document for Firestore
                let sessionMetadata: [String: Any] = [
                    "heatName": heatName,
                    "fileName": fileName,
                    "recordedDate": FieldValue.serverTimestamp(), // Universal Cloud Time
                    "lapDistanceMeters": totalDistance,
                    "storageDownloadURL": cloudURL.absoluteString,
                    "isSynced": true
                ]
                
                // 5. Save the document to the "sessions" database collection
                self.db.collection("sessions").addDocument(data: sessionMetadata) { error in
                    if let error = error {
                        print("❌ [Sidecar] Firestore Metadata Failed: \(error.localizedDescription)")
                    } else {
                        print("🏁 [Sidecar] Sync Complete. Session is now live in Apexiel Cloud.")
                    }
                }
            }
        }
    }
}
