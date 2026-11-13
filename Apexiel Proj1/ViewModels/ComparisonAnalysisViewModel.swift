//
//  ComparisonAnalysisViewModel.swift
//  Apexiel Proj1
//
//  Created by Kenji Fahselt on 2/18/26.
//

import SwiftUI
import MapKit
import CoreLocation



@MainActor // Ensures UI updates happen on the main thread
class ComparisonAnalysisViewModel: ObservableObject {

    
    // MARK: - INPUT DATA
    let lap1: [DrivingTelemDataPoint]
    let lap2: [DrivingTelemDataPoint]
    
    // MARK: - PUBLISHED STATE (The View Observes These @published wrapper for observable UI referesh)
    @Published var scrubbedPointL1: DrivingTelemDataPoint?
    @Published var scrubbedPointL2: DrivingTelemDataPoint?
    @Published var interactionDistance: Double?
    
    // Map Camera State
    @Published var cameraPosition: MapCameraPosition = .automatic
    
    // MARK: - COMPUTED PROPERTIES
    var maxLapDistance: Double {
        let maxL1 = lap1.last?.totalDistance ?? 0
        let maxL2 = lap2.last?.totalDistance ?? 0
        return max(maxL1, maxL2)
    }
    
    // MARK: - INITIALIZER
    init(lap1: [DrivingTelemDataPoint], lap2: [DrivingTelemDataPoint]) {
        self.lap1 = lap1
        self.lap2 = lap2
    }
    
    // MARK: - LOGIC METHODS
    
    /// Updates the scrubbed points based on the graph drag distance
    func syncMapToDistance(_ distance: Double) {
        // Clamp the distance to valid bounds
        let clampedDist = max(0, min(distance, maxLapDistance))
        
        self.interactionDistance = clampedDist
        
        // Find closest points
        self.scrubbedPointL1 = lap1.min(by: { abs($0.totalDistance - clampedDist) < abs($1.totalDistance - clampedDist) })
        self.scrubbedPointL2 = lap2.min(by: { abs($0.totalDistance - clampedDist) < abs($1.totalDistance - clampedDist) })
    }
    
    /// Shifts coordinates to create the "Ribbon" effect so laps dont overlap completely
    func shiftCoordinate(_ coord: CLLocationCoordinate2D, byMeters meters: Double) -> CLLocationCoordinate2D {
        let latOffset = meters / 111111.0
        let lonOffset = meters / (111111.0 * cos(coord.latitude * .pi / 180.0))
        return CLLocationCoordinate2D(latitude: coord.latitude + latOffset, longitude: coord.longitude + lonOffset)
    }
    
    /// Generates the opacity gradient based on speed
    func createSpeedGradient(for lap: [DrivingTelemDataPoint], baseColor: Color) -> Gradient {
        // 1. GUARD: Prevent the out-of-bounds crash if the array is empty
        guard !lap.isEmpty else {
            // Fallback to a solid, safe color while the data loads
            return Gradient(colors: [baseColor])
        }
        
        let maxSpeed = lap.map(\.speed).max() ?? 1.0
        let minSpeed = lap.map(\.speed).min() ?? 0.0
        let range = maxSpeed - minSpeed
        
        let sampleCount = 20
        var stops: [Gradient.Stop] = []
        
        for i in 0...sampleCount {
            // This math is now mathematically safe because lap.count is guaranteed to be >= 1
            let index = Int((Double(i) / Double(sampleCount)) * Double(lap.count - 1))
            let point = lap[index]
            
            // 2. GUARD: Prevent division by zero if the car never moved (range == 0)
            let normalizedSpeed = range > 0 ? (point.speed - minSpeed) / range : 1.0
            let opacity = 0.3 + (normalizedSpeed * 0.7)
            
            stops.append(.init(color: baseColor.opacity(opacity), location: Double(i) / Double(sampleCount)))
        }
        
        return Gradient(stops: stops)
    }
    
    /// Finds the closest telemetry point to a tapped map coordinate and syncs the UI (used for tapping the map)
        func snapToCoordinate(_ targetCoordinate: CLLocationCoordinate2D) {
            let targetLocation = CLLocation(latitude: targetCoordinate.latitude, longitude: targetCoordinate.longitude)
            
            var closestPhysicalDistance: CLLocationDistance = .infinity
            var closestLapDistance: Double = 0
            
            // Scan the base lap to find the nearest recorded point
            for point in lap1 {
                let pointLocation = CLLocation(latitude: point.coordinate.latitude, longitude: point.coordinate.longitude)
                let distanceToTap = targetLocation.distance(from: pointLocation)
                
                if distanceToTap < closestPhysicalDistance {
                    closestPhysicalDistance = distanceToTap
                    closestLapDistance = point.totalDistance
                }
            }
            
            // Re-use your existing sync function to update the scrubber dots and chart!
            syncMapToDistance(closestLapDistance)
        }
}
