//
//  DrivingLogicViewModel.swift
//  Apexiel Proj1
//
//  Created by Kenji Fahselt on 2/18/26.
//

import Foundation
import CoreLocation
import Combine
import FirebaseCrashlytics // Passive breadcrumb logging

/// **Purpose:**
/// The `DrivingLogicViewModel` acts as the central coordinator for real-time telemetry capture during a race.
/// It interfaces with the device's hardware to receive high-frequency GPS updates, translates that raw data
/// into immutable `DrivingTelemDataPoint` objects, and immediately delegates the saving process to the
/// stream recorder. It also drives the real-time UI (speedometer) during the race.
///
/// **Coupling:**
/// - **Data Model:** Tightly coupled to `DrivingTelemDataPoint`.
/// - **Storage:** Tightly coupled to `RaceSessionManager` for disk I/O.
/// - **Hardware:** Relies on `CLLocationManager` for device sensors.
/// - **UI:** Consumed by `CaptureView`. Drives UI updates and triggers navigation upon session completion.
@MainActor
class DrivingLogicViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    // MARK: - MEMBERS: STATE PROPERTIES (UI Bound)
    @Published var pointCount: Int = 0
    @Published var selectedHeat: String = "Heat 1"
    @Published var availableHeats: [String] = ["Practice", "Heat 1", "Heat 2", "Heat 3", "Final"]
  
    // Private state for the accumulator math
    @Published var previousLocation: CLLocation? = nil
    @Published var currentSessionDistance: Double = 0.0
    
    // Tracks if the "Black Box" is currently actively streaming to disk.
    @Published var isRecording: Bool = false
    // The current calculated speed in MPH, meant for the driver-facing speedometer.
    @Published var currentSpeed: Double = 0.0
    // Populated only when a session ends successfully. Triggers the View to transition.
    @Published var sessionSavedURL: URL?
    
    // MARK: - MEMBERS: DEPENDENCIES
    let locationManager = CLLocationManager()
    let sessionManager = RaceSessionManager() // Now an Actor!
    
    // MARK: - INITIALIZER
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.activityType = .automotiveNavigation
        locationManager.distanceFilter = kCLDistanceFilterNone
        // 1. Tell CoreLocation we want to run in the background
        locationManager.allowsBackgroundLocationUpdates = true
        // Prevent the OS from assuming we are parked at a red light and turning off the GPS
        locationManager.pausesLocationUpdatesAutomatically = false
        
        //  This forces the "Blue Pill" in the iOS status bar.
        // It legally allows "When In Use" apps to run indefinitely in the background.
        locationManager.showsBackgroundLocationIndicator = true
        // Request Permissions (Using "Always" is best for racing, but "When In Use" works perfectly as long as the Blue Pill is active)
        locationManager.requestWhenInUseAuthorization()
    }
    
    // MARK: - USER ACTIONS
    func toggleSession() {
        if isRecording {
            stopSession()
        } else {
            startSession()
        }
    }
    
    private func startSession() {
        Crashlytics.crashlytics().log("User initiated Start Session for heat: \(selectedHeat)")
        
        // Push disk creation to a background Task so it doesn't freeze the UI
        Task {
            // Await the thread-safe actor
            guard let newURL = await sessionManager.startNewSession(heatName: self.selectedHeat) else {
                let errorMsg = "Critical Error: Could not start recording stream"
                print("❌ \(errorMsg)")
                Crashlytics.crashlytics().log(errorMsg)
                return
            }
            
            // Hop back to the Main Thread to update the UI and start the hardware
            await MainActor.run {
                self.sessionSavedURL = nil
                self.isRecording = true
                self.pointCount = 0
                self.currentSessionDistance = 0.0
                self.previousLocation = nil
                
                locationManager.startUpdatingLocation()
                print("🏁 Session Started: \(newURL.lastPathComponent)")
            }
        }
    }
    
    private func stopSession() {
        Crashlytics.crashlytics().log("User initiated Stop Session. Points captured: \(pointCount)")
        
        // 1. Stop Hardware & Lock the Gate immediately
        locationManager.stopUpdatingLocation()
        self.isRecording = false
        
        // 2. Capture metrics before we wipe them
        let finalDistance = self.currentSessionDistance
        let activeHeat = self.selectedHeat
        
        // 3. Await the disk flush and fire the sidecar in the background
        Task {
            // Await the actor (guarantees the file is completely closed before moving on)
            guard let savedURL = await sessionManager.stopSession() else {
                print("⚠️ Error: Could not retrieve saved local session URL.")
                Crashlytics.crashlytics().log("Failed to retrieve currentFileURL on stopSession")
                return
            }
            
            // Update UI State (Handoff to Analysis Screen)
            await MainActor.run {
                self.sessionSavedURL = savedURL
                print("💾 Session Ready for Analysis: \(savedURL.lastPathComponent)")
                
                // Reset state to prevent session bleed
                self.pointCount = 0
                self.previousLocation = nil
                self.currentSessionDistance = 0.0
            }
            
            // ---------------------------------------------------------
            // 🔥 4. THE TRIPWIRE: The file is fully locked. Fire the Sidecar.
            // ---------------------------------------------------------
            CloudSyncManager.shared.syncSessionToCloud(
                localFileURL: savedURL,
                heatName: activeHeat,
                totalDistance: finalDistance
            )
        }
    }
    
    // MARK: - HARDWARE DELEGATE (The Capture Loop)
        
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task {
            // STEP 1: UI State & Math (On the Main Thread)
            let (totalDist, validSpeed, shouldRecord) = await MainActor.run {
                
                // 🔥 THE GATEKEEPER: If the user tapped stop a microsecond ago, abort!
                guard self.isRecording else { return (0.0, 0.0, false) }
                
                let speed = max(0, location.speed)
                
                if let prev = self.previousLocation {
                    let delta = location.distance(from: prev)
                    self.currentSessionDistance += delta
                }
                self.previousLocation = location
                
                self.currentSpeed = speed * 2.237
                self.pointCount += 1
                
                return (self.currentSessionDistance, speed, true)
            }
            
            // If the gatekeeper caught a phantom point, exit the task before touching the disk
            guard shouldRecord else { return }
            
            // STEP 2: Object Creation & Disk I/O
            let newPoint = DrivingTelemDataPoint(
                speed: validSpeed,
                timestamp: location.timestamp,
                acceleration: .zero,
                rotationRate: .zero,
                yaw: location.course,
                totalDistance: totalDist,
                coordinate: location.coordinate,
                heading: location.course
            )
            
            // Await the thread-safe actor
            await self.sessionManager.recordPoint(newPoint)
        }
    }
}
