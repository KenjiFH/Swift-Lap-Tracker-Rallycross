import SwiftUI
import Charts
//TODO get a value speed trace for BOTH laps
struct TelemetryGraphView: View {
    // Inputs
    let lap1: [DrivingTelemDataPoint]
    let lap2: [DrivingTelemDataPoint]
    
    // Scrubber State
    @State private var scrubbedDistance: Double?
    @State private var selectedPointL1: DrivingTelemDataPoint?
    @State private var selectedPointL2: DrivingTelemDataPoint?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            // 1. Dynamic Header
            HStack {
                Text("Speed Trace")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Live Delta Readout, we should also have it show speed
                if let p1 = selectedPointL1, let p2 = selectedPointL2 {
                    let delta = (p1.speed - p2.speed) * 2.237 // m/s to mph
                    let sign = delta > 0 ? "+" : ""
                    VStack{
                        //l1 speed data
                        Text("\(sign)\(String(format: "%.1f", p1.speed * 2.237)) mph")
                            .font(.system(.body, design: .monospaced).bold())
                            .foregroundStyle(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(6)
                        //l2 speed data
                        Text("\(sign)\(String(format: "%.1f", p2.speed * 2.237)) mph")
                            .font(.system(.body, design: .monospaced).bold())
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(6)
                        Text("\(sign)\(String(format: "%.1f", delta)) mph")
                            .font(.system(.body, design: .monospaced).bold())
                            .foregroundStyle(delta >= 0 ? .green : .red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(6)
                    }
                }
            }
            
            // 2. The Interactive Chart
            Chart {
                // Lap 1 (Red)
                ForEach(lap1) { point in
                    LineMark(
                        x: .value("Dist", point.totalDistance),
                        y: .value("Speed", point.speed * 2.237) // Convert to MPH
                    )
                    .foregroundStyle(by: .value("Lap", "Lap 1"))
                    .interpolationMethod(.linear)
                }
                
                // Lap 2 (Blue)
                ForEach(lap2) { point in
                    LineMark(
                        x: .value("Dist", point.totalDistance),
                        y: .value("Speed", point.speed * 2.237)
                    )
                    .foregroundStyle(by: .value("Lap", "Lap 2"))
                    .interpolationMethod(.linear)
                }
                
                // 3. The Scrubber Elements (Only when touching)
                if let currentDist = scrubbedDistance {
                    
                    // The Vertical Line
                    RuleMark(x: .value("Selected", currentDist))
                        .foregroundStyle(.gray.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    
                    // The Dot on Lap 1
                    if let p1 = selectedPointL1 {
                        PointMark(
                            x: .value("Dist", p1.totalDistance),
                            y: .value("Speed", p1.speed * 2.237)
                        )
                        .foregroundStyle(.red)
                        .symbolSize(100)
                    }
                    
                    // The Dot on Lap 2
                    if let p2 = selectedPointL2 {
                        PointMark(
                            x: .value("Dist", p2.totalDistance),
                            y: .value("Speed", p2.speed * 2.237)
                        )
                        .foregroundStyle(.blue)
                        .symbolSize(100)
                    }
                }
            }
            .chartForegroundStyleScale([
                "Lap 1": .red,
                "Lap 2": .blue
            ])
            .chartYAxisLabel("Speed (mph)")
            .chartXAxisLabel("Distance (m)")
            .frame(height: 280)
            
            // 4. Interaction Overlay
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    // A. Find where we are touching (Pixels -> X Value)
                                    let origin = geo[proxy.plotAreaFrame].origin
                                    let location = CGPoint(
                                        x: value.location.x - origin.x,
                                        y: value.location.y - origin.y
                                    )
                                    
                                    // B. Extract Distance from X-Axis
                                    if let dist: Double = proxy.value(atX: location.x) {
                                        self.scrubbedDistance = dist
                                        findClosestPoints(at: dist)
                                    }
                                }
                                .onEnded { _ in
                                    // Optional: Hide scrubber when letting go
                                    // self.scrubbedDistance = nil
                                    // self.selectedPointL1 = nil
                                }
                        )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // Helper: Find the data point closest to the finger
    private func findClosestPoints(at distance: Double) {
        // Simple linear search (fast enough for <2000 points)
        self.selectedPointL1 = lap1.min(by: {
            abs($0.totalDistance - distance) < abs($1.totalDistance - distance)
        })
        
        self.selectedPointL2 = lap2.min(by: {
            abs($0.totalDistance - distance) < abs($1.totalDistance - distance)
        })
        
        // Haptic Tick
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
#Preview {
    // Generate Mock Data for Preview
    let mockLap1 = DrivingTelemDataPoint.generateMockLap(duration: 60)
    // Create a "Slower" second lap for comparison
    var mockLap2 = DrivingTelemDataPoint.generateMockLapVariant(duration: 63)
    
    ZStack {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
        
        VStack {
            Text("Comparison Analysis")
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            
            TelemetryGraphView(lap1: mockLap1, lap2: mockLap2)
                .padding()
            
            Spacer()
        }
    }
}





