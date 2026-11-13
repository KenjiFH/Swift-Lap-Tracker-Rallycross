//
//  DrivingTelemetry.swift
//  Apexiel Proj1
//
//  Created by Kenji Fahselt on 7/13/25.
//


import Foundation
import CoreLocation



// 1. The Struct, created because we needed a custom GPS marker which contained speed,gyro, location and distance data
// we now made it codeable so we can save to JSON 
struct DrivingTelemDataPoint: Identifiable, Codable {
    
    // MARK: - Properties
    let id: UUID
    let speed: Double               // m/s
    let timestamp: Date
    let acceleration: SIMD3<Double> // G-Force
    let rotationRate: SIMD3<Double> // rad/s
    let yaw: Double?
    let totalDistance: Double       // X-AXIS
    
    // Location data
    let coordinate: CLLocationCoordinate2D
    let heading: Double?
    
    // MARK: - Manual Codable Implementation
    // We MUST do this manually because CLLocationCoordinate2D is not Codable by default
    
    enum CodingKeys: String, CodingKey {
        case id, speed, timestamp, acceleration, rotationRate, yaw, totalDistance, heading
        case latitude, longitude // We split 'coordinate' into these two
    }

    // 1. ENCODE (Saving to JSON)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(speed, forKey: .speed)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(acceleration, forKey: .acceleration)
        try container.encode(rotationRate, forKey: .rotationRate)
        try container.encode(yaw, forKey: .yaw)
        try container.encode(totalDistance, forKey: .totalDistance)
        try container.encode(heading, forKey: .heading)
        
        // Manual Coordinate Encoding
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
    }

    // 2. DECODE (Loading from JSON)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Initialize all 'let' properties here
        id = try container.decode(UUID.self, forKey: .id)
        speed = try container.decode(Double.self, forKey: .speed)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        acceleration = try container.decode(SIMD3<Double>.self, forKey: .acceleration)
        rotationRate = try container.decode(SIMD3<Double>.self, forKey: .rotationRate)
        yaw = try container.decodeIfPresent(Double.self, forKey: .yaw)
        totalDistance = try container.decode(Double.self, forKey: .totalDistance)
        heading = try container.decodeIfPresent(Double.self, forKey: .heading)
        
        // Rebuild Coordinate
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lon = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    // MARK: - Default Initializer
    // We need to explicitly add this back because adding a custom init(from:)
    // removes the default memberwise initializer.
    init(
        id: UUID = UUID(),
        speed: Double,
        timestamp: Date,
        acceleration: SIMD3<Double>,
        rotationRate: SIMD3<Double>,
        yaw: Double?,
        totalDistance: Double,
        coordinate: CLLocationCoordinate2D,
        heading: Double?
    ) {
        self.id = id
        self.speed = speed
        self.timestamp = timestamp
        self.acceleration = acceleration
        self.rotationRate = rotationRate
        self.yaw = yaw
        self.totalDistance = totalDistance
        self.coordinate = coordinate
        self.heading = heading
    }
}


// 2. The Mock Generator Extension
extension DrivingTelemDataPoint {
    
    static func generateMockLap(duration: TimeInterval = 60, timeOffset: TimeInterval = 0) -> [DrivingTelemDataPoint] {
        var points: [DrivingTelemDataPoint] = []
        let startDate = Date().addingTimeInterval(timeOffset)
        
        let frequency = 10.0 // 10Hz
        let steps = Int(duration * frequency)
        
        // Track Math
        let centerLat = 47.6062
        let centerLon = -122.3321
        let trackRadius = 0.0025
        var cumulativeDistance: Double = 0.0
        var prevCoordinate: CLLocationCoordinate2D?
        
        for i in 0..<steps {
            let time = Double(i) / frequency
            let progress = time / duration
            
            // Speed Physics (Slow in corners, Fast in straights)
            let baseSpeed = 35.0
            let speedVar = 10.0 * cos(progress * 4 * .pi)
            let currentSpeed = max(10.0, baseSpeed + speedVar)
            
            // Location Math (Figure 8-ish oval)
            let angle = progress * 2 * .pi
            let latOffset = trackRadius * cos(angle)
            let lonOffset = (trackRadius * 1.6) * sin(angle)
            let coord = CLLocationCoordinate2D(
                latitude: centerLat + latOffset,
                longitude: centerLon + lonOffset
            )
            
            // Calculate Distance (Cumulative)
            if let prev = prevCoordinate {
                let locA = CLLocation(latitude: prev.latitude, longitude: prev.longitude)
                let locB = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                cumulativeDistance += locA.distance(from: locB)
            }
            prevCoordinate = coord
            
            // Create Point
            let point = DrivingTelemDataPoint(
                speed: currentSpeed,
                timestamp: startDate.addingTimeInterval(time),
                acceleration: SIMD3<Double>(0, 0, 0), // Placeholder
                rotationRate: SIMD3<Double>(0, 0, 0),
                yaw: 0,
                totalDistance: cumulativeDistance, // <--- Key for Graph
                coordinate: coord,
                heading: 0
            )
            
            points.append(point)
        }
        
        return points
    }
    
    
    static func generateMockLapVariant(duration: TimeInterval = 62, timeOffset: TimeInterval = 0) -> [DrivingTelemDataPoint] {
            var points: [DrivingTelemDataPoint] = []
            let startDate = Date().addingTimeInterval(timeOffset)
            
            let frequency = 10.0
            let steps = Int(duration * frequency)
            
            // Track Math (Same Center)
            let centerLat = 47.6062
            let centerLon = -122.3321
            let trackRadius = 0.0025
            var cumulativeDistance: Double = 0.0
            var prevCoordinate: CLLocationCoordinate2D?
            
            for i in 0..<steps {
                let time = Double(i) / frequency
                let progress = time / duration
                
                // VARIANCE 1: Different Speed Profile
                // This driver brakes LATER but accelerates SLOWER (The "Dive Bomb" technique)
                // We shift the phase of the cosine wave slightly (+ 0.5)
                let baseSpeed = 33.0 // Slightly slower average
                let speedVar = 12.0 * cos((progress * 4 * .pi) + 0.5)
                // Add slight random noise to speed to test "jitter" smoothing
                let noise = Double.random(in: -0.5...0.5)
                let currentSpeed = max(8.0, baseSpeed + speedVar + noise)
                
                // VARIANCE 2: Different Racing Line
                // We multiply the radius by a slight factor to simulate taking a "Wider" line
                // Widens the track by ~5 meters at the apex
                let wideLineFactor = 1.0 + (0.05 * sin(progress * 2 * .pi))
                
                let angle = progress * 2 * .pi
                let latOffset = (trackRadius * wideLineFactor) * cos(angle)
                let lonOffset = ((trackRadius * 1.6) * wideLineFactor) * sin(angle)
                
                let coord = CLLocationCoordinate2D(
                    latitude: centerLat + latOffset,
                    longitude: centerLon + lonOffset
                )
                
                // Calculate Distance
                if let prev = prevCoordinate {
                    let locA = CLLocation(latitude: prev.latitude, longitude: prev.longitude)
                    let locB = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                    cumulativeDistance += locA.distance(from: locB)
                }
                prevCoordinate = coord
                
                let point = DrivingTelemDataPoint(
                    speed: currentSpeed,
                    timestamp: startDate.addingTimeInterval(time),
                    acceleration: SIMD3<Double>(0, 0, 0),
                    rotationRate: SIMD3<Double>(0, 0, 0),
                    yaw: 0,
                    totalDistance: cumulativeDistance,
                    coordinate: coord,
                    heading: 0
                )
                
                points.append(point)
            }
            
            return points
        }
    
    /// Generates a complex, non-circular Rallycross lap with realistic physics.
        /// - Parameters:
        ///   - duration: How long the lap takes (seconds)
        ///   - variance: How "messy" the driver is (0.0 = perfect line, 1.0 = all over the place)
        ///   - seed: Change this number to generate a completely different track layout
    ///
    ///   uses a "multi-frequency sine wave" approach to create a complex, blob-like track shape (instead of a circle).
    ///   It then calculates curvature to realistically slow the car down in tight corners and speed it up in straights.
        static func generateProceduralRallyLap(duration: TimeInterval = 65, variance: Double = 0.5, seed: Int = 1) -> [DrivingTelemDataPoint] {
            var points: [DrivingTelemDataPoint] = []
            let startDate = Date()
            
            let frequency = 10.0 // 10Hz data rate
            let steps = Int(duration * frequency)
            
            // Track Origin (Seattle - DirtFish Rally School approx location)
            let centerLat = 47.54
            let centerLon = -121.88
            
            // Track Shape Constants
            // We use multiple sine waves to create a "Squiggly" loop instead of a circle
            let trackScale = 0.003
            
            var cumulativeDistance: Double = 0.0
            var prevCoordinate: CLLocationCoordinate2D?
            
            for i in 0..<steps {
                let time = Double(i) / frequency
                let progress = Double(i) / Double(steps) // 0.0 to 1.0
                let angle = progress * 2 * .pi
                
                // ---------------------------------------------------------
                // 1. PROCEDURAL TRACK GENERATION (The "Base" Path)
                // ---------------------------------------------------------
                // We combine 3 sine waves to make a complex shape (The "Figure-8ish" look)
                // Seed affects the "shape" of the track
                let shapeMod = Double(seed % 5) + 1.0
                
                // Primary Oval
                var x = cos(angle)
                var y = sin(angle)
                
                // Add "Twists" (Turns)
                x += 0.4 * cos(3 * angle + shapeMod)
                y += 0.4 * sin(2 * angle)
                
                // ---------------------------------------------------------
                // 2. ADD DRIVER VARIANCE (The "Racing Line")
                // ---------------------------------------------------------
                // We add Perlin-like noise to simulate the driver drifting left/right
                let laneDrift = (sin(angle * 10) * 0.05) * variance
                x += laneDrift
                y += laneDrift
                
                // Scale to GPS coordinates
                let latOffset = y * trackScale
                let lonOffset = x * (trackScale * 1.6) // Longitude correction
                
                let coord = CLLocationCoordinate2D(
                    latitude: centerLat + latOffset,
                    longitude: centerLon + lonOffset
                )
                
                // ---------------------------------------------------------
                // 3. REALISTIC PHYSICS (Speed based on Curvature)
                // ---------------------------------------------------------
                // Calculate instantaneous curvature (How sharp is the turn?)
                // Sharp turn (high curvature) = Slow Speed. Straight = Fast Speed.
                
                // Derivative (approximate curvature magnitude)
                let dx = -sin(angle) - 1.2 * sin(3 * angle + shapeMod)
                let dy = cos(angle) + 0.8 * cos(2 * angle)
                let curvature = sqrt(dx*dx + dy*dy)
                
                // Map curvature to speed (Inverted: High curve = Low speed)
                // Straights: ~70mph (31 m/s), Hairpins: ~25mph (11 m/s)
                let baseSpeed = 35.0
                let corneringPenalty = curvature * 10.0
                let randomThrottle = Double.random(in: -1.0...1.0) * variance // Throttle noise
                
                // Clamp speed to realistic RX bounds
                let targetSpeed = max(10.0, baseSpeed - corneringPenalty + randomThrottle)
                
                // ---------------------------------------------------------
                // 4. ACCUMULATE DISTANCE
                // ---------------------------------------------------------
                if let prev = prevCoordinate {
                    let locA = CLLocation(latitude: prev.latitude, longitude: prev.longitude)
                    let locB = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                    cumulativeDistance += locA.distance(from: locB)
                }
                prevCoordinate = coord
                
                // ---------------------------------------------------------
                // 5. BUILD POINT
                // ---------------------------------------------------------
                let point = DrivingTelemDataPoint(
                    speed: targetSpeed,
                    timestamp: startDate.addingTimeInterval(time),
                    acceleration: SIMD3<Double>(0, 0, 0), // Placeholder
                    rotationRate: SIMD3<Double>(0, 0, 0), // Placeholder
                    yaw: 0,
                    totalDistance: cumulativeDistance, // Crucial for X-Axis
                    coordinate: coord,
                    heading: 0
                )
                
                points.append(point)
            }
            
            return points
        }
}


//legacy struct for backwards compatibility with turnlogic and turnrender VMS
struct MotionData: Identifiable {
    let id = UUID()
    let timestamp: Date
    let acceleration: SIMD3<Double> // x, y, z
    let rotationRate: SIMD3<Double> // x, y, z
    let yaw: Double? // if using fused yaw later
}

struct LocationData: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let speed: Double
    let heading: Double?
    let timestamp: Date
}


