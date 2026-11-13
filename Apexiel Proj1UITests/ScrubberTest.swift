import SwiftUI
import MapKit
import Charts
import CoreLocation

/*
struct ComparisonAnalysisViewTest: View {
    // INPUT DATA
    let lap1: [DrivingTelemDataPoint] // Red Lap
    let lap2: [DrivingTelemDataPoint] // Blue Lap
    
    // SHARED STATE
    @State private var scrubbedPointL1: DrivingTelemDataPoint?
    @State private var scrubbedPointL2: DrivingTelemDataPoint?
    @State private var interactionDistance: Double?
    
    // MAP STATE
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    // HELPER: Max Distance for Clamping
    var maxLapDistance: Double {
        let maxL1 = lap1.last?.totalDistance ?? 0
        let maxL2 = lap2.last?.totalDistance ?? 0
        return max(maxL1, maxL2)
    }

    var body: some View {
        VStack(spacing: 0) {
            
            // ---------------------------------------------------------
            // 1. THE MAP VIEW
            // ---------------------------------------------------------
            Map(position: $cameraPosition) {
                
                // LAP 1 (RED) - The "Reference" Line
                // Drawn exactly on the GPS coordinates
                MapPolyline(coordinates: lap1.map(\.coordinate))
                    .stroke(
                        // Dynamic Gradient: Lighter = Slow, Darker = Fast
                        createSpeedGradient(for: lap1, baseColor: .red),
                        lineWidth: 4
                    )
                
                // LAP 2 (BLUE) - The "Challenger" Line
                // SHIFTED by 3 meters to create the "Ribbon" effect so it doesn't overlap
                MapPolyline(coordinates: lap2.map {
                    shiftCoordinate($0.coordinate, byMeters: 3.0)
                })
                .stroke(
                    createSpeedGradient(for: lap2, baseColor: .blue),
                    lineWidth: 4
                )
                
                // Draw the Scrubber Dots (Ghost Cars)
                if let p1 = scrubbedPointL1 {
                    Annotation("Lap 1", coordinate: p1.coordinate) {
                        ScrubberDot(color: .red)
                    }
                }
                
                if let p2 = scrubbedPointL2 {
                    // Important: Shift the Blue Dot too, so it stays on the Blue Line!
                    Annotation("Lap 2", coordinate: shiftCoordinate(p2.coordinate, byMeters: 3.0)) {
                        ScrubberDot(color: .blue)
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .frame(height: 350)
            
            // ---------------------------------------------------------
            // 2. THE GRAPH VIEW
            // ---------------------------------------------------------
            VStack(alignment: .leading) {
                HStack {
                    Text("Speed Trace")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    
                    // Live Delta Readout
                    if let p1 = scrubbedPointL1, let p2 = scrubbedPointL2 {
                        let delta = (p1.speed - p2.speed) * 2.237 // m/s to mph
                        let sign = delta > 0 ? "+" : ""
                        
                        HStack {
                            SpeedBadge(speed: p1.speed, color: .red)
                            SpeedBadge(speed: p2.speed, color: .blue)
                            
                            Text("\(sign)\(String(format: "%.1f", delta))")
                                .font(.system(.body, design: .monospaced).bold())
                                .foregroundStyle(delta >= 0 ? .green : .red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(6)
                        }
                    }
                }
                
                Chart {
                    // Lap 1 (Red)
                    ForEach(lap1) { point in
                        LineMark(
                            x: .value("Dist", point.totalDistance),
                            y: .value("Speed", point.speed * 2.237)
                        )
                        .interpolationMethod(.linear)
                        .foregroundStyle(by: .value("Lap", "Lap 1"))
                    }
                    
                    // Lap 2 (Blue)
                    ForEach(lap2) { point in
                        LineMark(
                            x: .value("Dist", point.totalDistance),
                            y: .value("Speed", point.speed * 2.237)
                        )
                        .interpolationMethod(.linear)
                        .foregroundStyle(by: .value("Lap", "Lap 2"))
                    }
                    
                    // The Scrubber Line (Snapped to Data)
                    if let primaryPoint = scrubbedPointL1 {
                        RuleMark(x: .value("Selected", primaryPoint.totalDistance))
                            .foregroundStyle(.gray.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                        
                        PointMark(
                            x: .value("Dist", primaryPoint.totalDistance),
                            y: .value("Speed", primaryPoint.speed * 2.237)
                        )
                        .foregroundStyle(.red)
                        .symbolSize(100)
                        
                        if let p2 = scrubbedPointL2 {
                            PointMark(
                                x: .value("Dist", p2.totalDistance),
                                y: .value("Speed", p2.speed * 2.237)
                            )
                            .foregroundStyle(.blue)
                            .symbolSize(100)
                        }
                    }
                }
                .chartForegroundStyleScale(["Lap 1": .red, "Lap 2": .blue])
                .chartXScale(domain: 0...maxLapDistance) // Lock Axis
                .chartYAxisLabel("Speed (mph)")
                .chartXAxisLabel("Distance (m)")
                .frame(height: 250)
                .padding()
                
                // Interaction Overlay
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let origin = geo[proxy.plotAreaFrame].origin
                                        let xPos = value.location.x - origin.x
                                        
                                        if let dist: Double = proxy.value(atX: xPos) {
                                            // CLAMPING LOGIC: Prevents "Runoff"
                                            let clampedDist = max(0, min(dist, maxLapDistance))
                                            self.interactionDistance = clampedDist
                                            self.syncMapToDistance(clampedDist)
                                        }
                                    }
                            )
                    }
                }
            }
            .background(Color(.systemBackground))
        }
        .ignoresSafeArea(edges: .top)
    }
    
    // MARK: - LOGIC HELPERS
    
    func syncMapToDistance(_ distance: Double) {
        self.scrubbedPointL1 = lap1.min(by: { abs($0.totalDistance - distance) < abs($1.totalDistance - distance) })
        self.scrubbedPointL2 = lap2.min(by: { abs($0.totalDistance - distance) < abs($1.totalDistance - distance) })
    }
    
    /// Generates a gradient where Opacity is mapped to Speed
    /// Slower = More Transparent (0.3), Faster = More Solid (1.0)
    func createSpeedGradient(for lap: [DrivingTelemDataPoint], baseColor: Color) -> Gradient {
        let maxSpeed = lap.map(\.speed).max() ?? 1.0
        let minSpeed = lap.map(\.speed).min() ?? 0.0
        let range = maxSpeed - minSpeed
        
        // We sample the lap at ~20 points to create the gradient stops
        // (Too many stops can hurt performance)
        let sampleCount = 20
        var stops: [Gradient.Stop] = []
        
        for i in 0...sampleCount {
            let index = Int((Double(i) / Double(sampleCount)) * Double(lap.count - 1))
            let point = lap[index]
            
            // Normalize Speed (0.0 to 1.0)
            let normalizedSpeed = (point.speed - minSpeed) / range
            
            // Map to Opacity (0.3 to 1.0)
            let opacity = 0.3 + (normalizedSpeed * 0.7)
            
            stops.append(.init(color: baseColor.opacity(opacity), location: Double(i) / Double(sampleCount)))
        }
        
        return Gradient(stops: stops)
    }
    
    /// Mathematically shifts a GPS coordinate to the "Right" by X meters
    /// Used to create the "Ribbon" effect so lines don't overlap
    func shiftCoordinate(_ coord: CLLocationCoordinate2D, byMeters meters: Double) -> CLLocationCoordinate2D {
        // Rough estimation: 1 deg Lat ~= 111km
        let latOffset = meters / 111111.0
        let lonOffset = meters / (111111.0 * cos(coord.latitude * .pi / 180.0))
        
        // Shift North-East to ensure visibility
        return CLLocationCoordinate2D(
            latitude: coord.latitude + latOffset,
            longitude: coord.longitude + lonOffset
        )
    }
}

// MARK: - UI COMPONENTS

struct ScrubberDotTest: View {
    let color: Color
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 14, height: 14)
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .shadow(radius: 3)
    }
}

struct SpeedBadgeTest: View {
    let speed: Double
    let color: Color
    var body: some View {
        Text("\(Int(speed * 2.237))")
            .font(.system(.caption, design: .monospaced).bold())
            .foregroundStyle(.white)
            .padding(4)
            .background(color)
            .cornerRadius(4)
    }
}

#Preview {
    
    let lap1 = DrivingTelemDataPoint.generateProceduralRallyLap(
        duration: 65,
        variance: 0.8,
        seed: 1
    )
    let lap2 = DrivingTelemDataPoint.generateProceduralRallyLap(
        duration: 62,
        variance: 0.2,
        seed: 1
    )
    return ComparisonAnalysisViewTest(lap1: lap1, lap2: lap2)
}
*/
