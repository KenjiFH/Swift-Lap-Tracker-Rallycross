import SwiftUI
import MapKit
import Charts

// MARK: - NEW: DELTA DATA MODEL
struct DeltaPoint: Identifiable {
    let id = UUID()
    let distance: Double
    let speedDelta: Double // mph (Positive = Faster, Negative = Slower)
}

struct ComparisonAnalysisView: View {
    
    @StateObject private var vm: ComparisonAnalysisViewModel
    @State private var showStatsSheet = false
    
    // NEW: State to hold the computed difference between Lap 2 and Lap 1
    @State private var deltaData: [DeltaPoint] = []
    
    init(lap1: [DrivingTelemDataPoint], lap2: [DrivingTelemDataPoint]) {
        _vm = StateObject(wrappedValue: ComparisonAnalysisViewModel(lap1: lap1, lap2: lap2))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            mapSection
            
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                chartSection // Refactored to include both charts
            }
            .background(Color(uiColor: .systemGray6))
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Comparison")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showStatsSheet = true
                } label: {
                    Image(systemName: "list.number")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showStatsSheet) {
            HeadToHeadStatsSheet(lap1: vm.lap1, lap2: vm.lap2)
                .presentationDetents([.fraction(0.4), .medium])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            generateDeltaData()
        }
    }
    
    // MARK: - 1. MAP SECTION
    @ViewBuilder
    private var mapSection: some View {
        MapReader { proxy in
            Map(position: $vm.cameraPosition) {
                
                // LAP 1 BASE (WHITE)
                MapPolyline(coordinates: vm.lap1.map(\.coordinate))
                    .stroke(vm.createSpeedGradient(for: vm.lap1, baseColor: .white), lineWidth: 4)
                
                // LAP 2 COMPARE (RED)
                MapPolyline(coordinates: vm.lap2.map { vm.shiftCoordinate($0.coordinate, byMeters: 3.0) })
                    .stroke(vm.createSpeedGradient(for: vm.lap2, baseColor: .red), lineWidth: 4)
                
                // Single Segment Callout Popup
                if let p1 = vm.scrubbedPointL1, let p2 = vm.scrubbedPointL2 {
                    Annotation("", coordinate: p1.coordinate) {
                        MapCalloutView(p1: p1, p2: p2)
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
            .colorScheme(.dark)
            .onTapGesture { screenCoordinate in
                if let tappedGPSCoordinate = proxy.convert(screenCoordinate, from: .local) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    vm.snapToCoordinate(tappedGPSCoordinate)
                }
            }
        }
    }
    
    // MARK: - 2. HEADER SECTION
    @ViewBuilder
    private var headerSection: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SPEED TRACE")
                    .font(.caption).bold()
                    .foregroundStyle(.gray)
                
                HStack(spacing: 12) {
                    LegendItem(color: .white, label: "Base")
                    LegendItem(color: .red, label: "Compare")
                }
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 20)
    }
    
    // MARK: - 3. CHART SECTION (Speed + Delta)
    @ViewBuilder
    private var chartSection: some View {
        VStack(spacing: 12) {
            speedChart
                .frame(height: 160)
            
            deltaChart
                .frame(height: 80)
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
    
    // MARK: Speed Chart
    private var speedChart: some View {
        Chart {
            // Lap 1 (White)
            ForEach(vm.lap1) { point in
                LineMark(
                    x: .value("Dist", point.totalDistance),
                    y: .value("Speed", point.speed * 2.237)
                )
                .interpolationMethod(.linear)
                .foregroundStyle(by: .value("Lap", "Base"))
            }
            
            // Lap 2 (Red)
            ForEach(vm.lap2) { point in
                LineMark(
                    x: .value("Dist", point.totalDistance),
                    y: .value("Speed", point.speed * 2.237)
                )
                .interpolationMethod(.linear)
                .foregroundStyle(by: .value("Lap", "Compare"))
            }
            
            // The Scrubber Line
            if let primaryPoint = vm.scrubbedPointL1 {
                RuleMark(x: .value("Selected", primaryPoint.totalDistance))
                    .foregroundStyle(.gray.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                
                PointMark(
                    x: .value("Dist", primaryPoint.totalDistance),
                    y: .value("Speed", primaryPoint.speed * 2.237)
                )
                .foregroundStyle(.white)
                .symbolSize(100)
                
                if let p2 = vm.scrubbedPointL2 {
                    PointMark(
                        x: .value("Dist", p2.totalDistance),
                        y: .value("Speed", p2.speed * 2.237)
                    )
                    .foregroundStyle(.red)
                    .symbolSize(100)
                }
            }
        }
        .chartForegroundStyleScale(["Base": .white, "Compare": .red])
        .chartLegend(.hidden)
        .chartXScale(domain: 0...vm.maxLapDistance)
        .chartYAxisLabel(position: .trailing) { Text("mph").font(.caption).foregroundStyle(.gray) }
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(.gray.opacity(0.2))
                // Deliberately hiding X-Axis labels here so it sits flush with the Delta chart
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(.gray.opacity(0.2))
                AxisValueLabel().foregroundStyle(.gray)
            }
        }
        .chartOverlay { proxy in scrubberOverlay(proxy: proxy) }
    }
    
    // MARK: Delta Chart
    private var deltaChart: some View {
        Chart {
            ForEach(deltaData) { dp in
                // Using BarMark creates a dense area-chart look that easily colors positive/negative
                BarMark(
                    x: .value("Dist", dp.distance),
                    y: .value("Delta", dp.speedDelta)
                )
                .foregroundStyle(dp.speedDelta >= 0 ? Color.green.opacity(0.8) : Color.red.opacity(0.8))
            }
            
            // The Scrubber Line (Syncs with top chart)
            if let p1 = vm.scrubbedPointL1, let p2 = vm.scrubbedPointL2 {
                let currentDelta = (p2.speed - p1.speed) * 2.237
                
                RuleMark(x: .value("Selected", p1.totalDistance))
                    .foregroundStyle(.gray.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                
                PointMark(
                    x: .value("Dist", p1.totalDistance),
                    y: .value("Delta", currentDelta)
                )
                .foregroundStyle(currentDelta >= 0 ? .green : .red)
                .symbolSize(100)
            }
        }
        .chartXScale(domain: 0...vm.maxLapDistance)
        .chartYAxisLabel(position: .trailing) { Text("Δ mph").font(.caption).foregroundStyle(.gray) }
        .chartXAxisLabel(position: .bottom) { Text("Distance (m)").font(.caption).foregroundStyle(.gray) }
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(.gray.opacity(0.2))
                AxisValueLabel().foregroundStyle(.gray) // Show labels on the bottom chart only
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(.gray.opacity(0.2))
                AxisValueLabel().foregroundStyle(.gray)
            }
        }
        .chartOverlay { proxy in scrubberOverlay(proxy: proxy) }
    }
    
    // MARK: Reusable Scrubber Drag Gesture
    private func scrubberOverlay(proxy: ChartProxy) -> some View {
        GeometryReader { geo in
            Rectangle().fill(.clear).contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let plotFrame = proxy.plotAreaFrame
                            let origin: CGPoint = geo[plotFrame].origin
                            let location: CGPoint = value.location
                            let xPos: CGFloat = location.x - origin.x
                            
                            if let dist: Double = proxy.value(atX: xPos) {
                                vm.syncMapToDistance(dist)
                            }
                        }
                )
        }
    }
    
    // MARK: - DATA GENERATION
    /// Calculates the speed difference between the two laps at aligned distances
    private func generateDeltaData() {
        Task.detached(priority: .userInitiated) {
            let generated = vm.lap1.compactMap { p1 -> DeltaPoint? in
                let targetDist = p1.totalDistance
                // Find the closest point in lap 2 based on distance
                guard let closestP2 = vm.lap2.min(by: { abs($0.totalDistance - targetDist) < abs($1.totalDistance - targetDist) }) else {
                    return nil
                }
                
                let speed1 = p1.speed * 2.237
                let speed2 = closestP2.speed * 2.237
                let delta = speed2 - speed1
                
                return DeltaPoint(distance: targetDist, speedDelta: delta)
            }
            
            await MainActor.run {
                self.deltaData = generated
            }
        }
    }
}

// MARK: - SINGLE SEGMENT MAP CALLOUT (With Anti-Clipping)
struct MapCalloutView: View {
    let p1: DrivingTelemDataPoint
    let p2: DrivingTelemDataPoint
    @State private var shiftOffset: CGFloat = 0
    
    var body: some View {
        let s1 = p1.speed * 2.237
        let s2 = p2.speed * 2.237
        let delta = s2 - s1
        let isFaster = delta >= 0
        let sign = isFaster ? "+" : ""
        
        VStack(spacing: 0) {
            // 1. THE DATA BOX
            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text("BASE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.gray)
                    Text("\(Int(s1))")
                        .font(.system(.subheadline, design: .monospaced).weight(.heavy))
                        .foregroundStyle(.black)
                        .frame(width: 32, height: 28)
                        .background(Color.white)
                        .cornerRadius(6)
                }
                VStack(spacing: 2) {
                    Text("CMP")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.gray)
                    Text("\(Int(s2))")
                        .font(.system(.subheadline, design: .monospaced).weight(.heavy))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 28)
                        .background(Color.red)
                        .cornerRadius(6)
                }
                VStack(alignment: .trailing, spacing: 2) {
                    Text("DELTA")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.gray)
                    Text("\(sign)\(String(format: "%.1f", delta))")
                        .font(.system(.headline, design: .monospaced).bold())
                        .foregroundStyle(isFaster ? .green : .red)
                        .frame(minWidth: 55, alignment: .trailing)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(white: 0.1).opacity(0.95))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
            .offset(x: shiftOffset)
            
            // 2. THE POINTER
            Triangle()
                .fill(Color(white: 0.1).opacity(0.95))
                .frame(width: 14, height: 8)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
                .offset(y: -1)
        }
        .offset(y: -40)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { calculateShift(frame: geo.frame(in: .global)) }
                    .onChange(of: geo.frame(in: .global)) { _, newFrame in calculateShift(frame: newFrame) }
            }
        )
    }
    
    private func calculateShift(frame: CGRect) {
        let screenWidth = UIScreen.main.bounds.width
        let margin: CGFloat = 16
        if frame.minX < margin {
            shiftOffset = margin - frame.minX
        } else if frame.maxX > screenWidth - margin {
            shiftOffset = (screenWidth - margin) - frame.maxX
        } else {
            shiftOffset = 0
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - HEAD TO HEAD STATS MODAL
struct HeadToHeadStatsSheet: View {
    let lap1: [DrivingTelemDataPoint]
    let lap2: [DrivingTelemDataPoint]
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGray6).ignoresSafeArea()
            VStack(spacing: 0) {
                Text("HEAD TO HEAD")
                    .font(.caption.bold())
                    .foregroundStyle(.gray)
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                
                HStack {
                    Text("METRIC").frame(maxWidth: .infinity, alignment: .leading)
                    Text("BASE").frame(width: 80, alignment: .trailing)
                    Text("COMPARE").frame(width: 80, alignment: .trailing)
                }
                .font(.caption2.bold())
                .foregroundStyle(.gray)
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                Divider().background(Color.gray.opacity(0.3))
                
                ScrollView {
                    VStack(spacing: 0) {
                        StatRow(title: "Lap Time", val1: formatTime(duration(for: lap1)), val2: formatTime(duration(for: lap2)), isBetter: duration(for: lap2) < duration(for: lap1))
                        StatRow(title: "Max Speed (mph)", val1: String(format: "%.0f", maxSpeed(for: lap1)), val2: String(format: "%.0f", maxSpeed(for: lap2)), isBetter: maxSpeed(for: lap2) > maxSpeed(for: lap1))
                        StatRow(title: "Avg Speed (mph)", val1: String(format: "%.1f", avgSpeed(for: lap1)), val2: String(format: "%.1f", avgSpeed(for: lap2)), isBetter: avgSpeed(for: lap2) > avgSpeed(for: lap1))
                        StatRow(title: "Distance (mi)", val1: String(format: "%.2f", distance(for: lap1)), val2: String(format: "%.2f", distance(for: lap2)), isBetter: nil)
                    }
                }
            }
        }
    }
    
    func duration(for lap: [DrivingTelemDataPoint]) -> TimeInterval {
        guard let first = lap.first?.timestamp, let last = lap.last?.timestamp else { return 0 }
        return last.timeIntervalSince(first)
    }
    func maxSpeed(for lap: [DrivingTelemDataPoint]) -> Double { (lap.map(\.speed).max() ?? 0) * 2.237 }
    func avgSpeed(for lap: [DrivingTelemDataPoint]) -> Double {
        guard !lap.isEmpty else { return 0 }
        return (lap.map(\.speed).reduce(0, +) / Double(lap.count)) * 2.237
    }
    func distance(for lap: [DrivingTelemDataPoint]) -> Double { (lap.last?.totalDistance ?? 0) * 0.000621371 }
    func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        let tenths = Int((interval.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}

// MARK: - UTILITY COMPONENTS
struct StatRow: View {
    let title: String; let val1: String; let val2: String; let isBetter: Bool?
    var body: some View {
        HStack {
            Text(title).font(.subheadline).foregroundStyle(.gray).frame(maxWidth: .infinity, alignment: .leading)
            Text(val1).font(.system(.subheadline, design: .monospaced).bold()).foregroundStyle(.white).frame(width: 80, alignment: .trailing)
            Text(val2).font(.system(.subheadline, design: .monospaced).bold()).foregroundStyle(isBetter == nil ? .white : (isBetter! ? .green : .red)).frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal).padding(.vertical, 16)
        .border(width: 1, edges: [.bottom], color: Color.gray.opacity(0.15))
    }
}

extension View {
    func border(width: CGFloat, edges: [Edge], color: Color) -> some View {
        overlay(EdgeBorder(width: width, edges: edges).foregroundColor(color))
    }
}

struct EdgeBorder: Shape {
    var width: CGFloat; var edges: [Edge]
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for edge in edges {
            var x: CGFloat { switch edge { case .top, .bottom, .leading: return rect.minX; case .trailing: return rect.maxX - width } }
            var y: CGFloat { switch edge { case .top, .leading, .trailing: return rect.minY; case .bottom: return rect.maxY - width } }
            var w: CGFloat { switch edge { case .top, .bottom: return rect.width; case .leading, .trailing: return width } }
            var h: CGFloat { switch edge { case .top, .bottom: return width; case .leading, .trailing: return rect.height } }
            path.addRect(CGRect(x: x, y: y, width: w, height: h))
        }
        return path
    }
}

struct LegendItem: View {
    let color: Color; let label: String
    var body: some View {
        HStack(spacing: 4) { Circle().fill(color).frame(width: 8, height: 8); Text(label).font(.caption2).bold().foregroundStyle(.white) }
    }
}

// MARK: - PREVIEW
#Preview {
    let lap1 = DrivingTelemDataPoint.generateProceduralRallyLap(duration: 65, variance: 0.8, seed: 1)
    let lap2 = DrivingTelemDataPoint.generateProceduralRallyLap(duration: 62, variance: 0.2, seed: 1)
    return NavigationStack {
        ComparisonAnalysisView(lap1: lap1, lap2: lap2)
            .preferredColorScheme(.dark)
    }
}
