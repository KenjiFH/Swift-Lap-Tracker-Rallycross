import SwiftUI
import MapKit

//this is a summary of your selected heat ingested from HeatDash for the specific heat you selected, CTA button at the bottom activates modal popup which which allows you to select another lap then it navigates to the comparison screen 
struct SessionSummaryView: View {
    // MARK: - MOCK DATA
    let laps: [[DrivingTelemDataPoint]]
    
    // MARK: - STATE
    @State private var selectedLapIndex: Int = 0
    
    // MVP Scrollbar State
    @State private var scrollProgress: CGFloat = 0.0
    @State private var isScrollable: Bool = false
    
    // Compare Navigation State
    @State private var showCompareSheet = false
    @State private var navigateToComparison = false
    @State private var targetCompareIndex: Int = 0
    
    var currentLap: [DrivingTelemDataPoint] {
        laps.isEmpty ? [] : laps[selectedLapIndex]
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // ------------------------------------------------
                    // 1. TRACK MAP
                    // ------------------------------------------------
                    // UX Improve: interactionModes: [] prevents accidental panning/zooming when trying to scroll
                    Map(interactionModes: []) {
                        if !currentLap.isEmpty {
                            MapPolyline(coordinates: currentLap.map(\.coordinate))
                                // UX Improve: Rounded caps make the GPS trace look much smoother
                                .stroke(.red, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                        }
                    }
                    .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
                    .frame(height: 300)
                    .colorScheme(.dark)
                    
                    // ------------------------------------------------
                    // 2. DASHBOARD
                    // ------------------------------------------------
                    VStack(spacing: 20) {
                        HStack(spacing: 40) {
                            DashboardStat(title: "MAX SPEED", value: String(format: "%.0f", maxSpeed(for: currentLap)), unit: "mph")
                            DashboardStat(title: "AVG SPEED", value: String(format: "%.0f", avgSpeed(for: currentLap)), unit: "mph")
                            DashboardStat(title: "DISTANCE", value: String(format: "%.2f", distance(for: currentLap)), unit: "mi")
                        }
                        .padding(.top, 24)
                        
                        Divider().background(Color.gray.opacity(0.3))
                        
                        // ------------------------------------------------
                        // 3. LAP TAPE (MVP Scrollbar)
                        // ------------------------------------------------
                        VStack(alignment: .leading, spacing: 12) {
                            Text("LAP TAPE")
                                .font(.caption).bold()
                                .foregroundStyle(.gray)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(0..<laps.count, id: \.self) { index in
                                        LapTapeCard(
                                            lapNumber: index + 1,
                                            duration: duration(for: laps[index]),
                                            isSelected: selectedLapIndex == index
                                        )
                                        .onTapGesture {
                                            // Selection haptic
                                            let impact = UIImpactFeedbackGenerator(style: .light)
                                            impact.impactOccurred()
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                selectedLapIndex = index
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .scrollTargetLayout()
                            }
                            .scrollTargetBehavior(.viewAligned)
                            .onScrollGeometryChange(for: CGFloat.self) { geo in
                                let maxScroll = geo.contentSize.width - geo.containerSize.width
                                return maxScroll > 0 ? geo.contentOffset.x / maxScroll : -1
                            } action: { _, newValue in
                                if newValue == -1 {
                                    isScrollable = false
                                } else {
                                    isScrollable = true
                                    scrollProgress = min(max(newValue, 0), 1)
                                }
                            }
                            // Scrollbar Edge-Bump Haptic
                            .onChange(of: scrollProgress) { oldValue, newValue in
                                // Trigger a solid "thud" when the scrollbar hits either extreme edge
                                if (oldValue > 0.02 && newValue <= 0) || (oldValue < 0.98 && newValue >= 1) {
                                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.7)
                                }
                            }
                            
                            // Scrollbar UI
                            if isScrollable {
                                GeometryReader { geo in
                                    let trackWidth = geo.size.width
                                    let indicatorWidth: CGFloat = 40
                                    let maxTravel = trackWidth - indicatorWidth
                                    
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.gray.opacity(0.3))
                                        Capsule().fill(Color.red)
                                            .frame(width: indicatorWidth)
                                            .offset(x: scrollProgress * maxTravel)
                                    }
                                }
                                .frame(height: 4)
                                .padding(.horizontal)
                            } else {
                                Color.clear.frame(height: 4).padding(.horizontal)
                            }
                        }
                        
                        Spacer()
                        
                        // ------------------------------------------------
                        // 4. COMPARE LAPS CTA
                        // ------------------------------------------------
                        Button {
                            // Button press haptic
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showCompareSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "arrow.left.and.right")
                                Text("COMPARE LAPS")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                        }
                        .buttonStyle(RacingScaleButtonStyle()) // UX Improve: visual tap confirmation
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                    .background(Color(uiColor: .systemGray6).opacity(0.1))
                }
            }
            .navigationTitle("Session Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            
            // THE BOTTOM SHEET
            .sheet(isPresented: $showCompareSheet) {
                CompareSelectionSheet(
                    baseLapIndex: selectedLapIndex,
                    laps: laps,
                    onLapSelected: { selectedIndex in
                        showCompareSheet = false
                        targetCompareIndex = selectedIndex
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            navigateToComparison = true
                        }
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            
            // THE ACTUAL NAVIGATION
            .navigationDestination(isPresented: $navigateToComparison) {
                ComparisonAnalysisView(
                    lap1: laps[selectedLapIndex],
                    lap2: laps[targetCompareIndex]
                )
            }
        }
    }
    
    // MARK: - LOGIC HELPERS
    func maxSpeed(for lap: [DrivingTelemDataPoint]) -> Double { (lap.map(\.speed).max() ?? 0) * 2.237 }
    func avgSpeed(for lap: [DrivingTelemDataPoint]) -> Double {
        guard !lap.isEmpty else { return 0 }
        return (lap.map(\.speed).reduce(0, +) / Double(lap.count)) * 2.237
    }
    func distance(for lap: [DrivingTelemDataPoint]) -> Double { (lap.last?.totalDistance ?? 0) * 0.000621371 }
    func duration(for lap: [DrivingTelemDataPoint]) -> TimeInterval {
        guard let first = lap.first?.timestamp, let last = lap.last?.timestamp else { return 0 }
        return last.timeIntervalSince(first)
    }
}

// MARK: - CUSTOM BUTTON STYLE (Visual Feedback)
struct RacingScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - COMPARE SELECTION SHEET (The 2-Tap UI)
struct CompareSelectionSheet: View {
    let baseLapIndex: Int
    let laps: [[DrivingTelemDataPoint]]
    let onLapSelected: (Int) -> Void
    
    var baseDuration: TimeInterval {
        duration(for: laps[baseLapIndex])
    }
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGray6).ignoresSafeArea()
            
            VStack(spacing: 16) {
                Text("Compare with Lap \(baseLapIndex + 1)")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.top, 24)
                
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(0..<laps.count, id: \.self) { index in
                            if index != baseLapIndex {
                                LapCompareRow(
                                    lapNumber: index + 1,
                                    targetDuration: duration(for: laps[index]),
                                    baseDuration: baseDuration
                                )
                                // Convert row tap into a button to get built-in highlight states
                                .onTapGesture {
                                    let impact = UIImpactFeedbackGenerator(style: .medium)
                                    impact.impactOccurred()
                                    onLapSelected(index)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
        }
    }
    
    func duration(for lap: [DrivingTelemDataPoint]) -> TimeInterval {
        guard let first = lap.first?.timestamp, let last = lap.last?.timestamp else { return 0 }
        return last.timeIntervalSince(first)
    }
}

// MARK: - COMPARE ROW SUBVIEW
struct LapCompareRow: View {
    let lapNumber: Int
    let targetDuration: TimeInterval
    let baseDuration: TimeInterval
    
    var delta: TimeInterval {
        targetDuration - baseDuration
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatTime(targetDuration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.gray)
                Text("Lap \(lapNumber)")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            
            Spacer()
            
            Text(formatDelta(delta))
                .font(.headline.monospacedDigit())
                .foregroundStyle(delta < 0 ? .green : (delta > 0 ? .red : .gray))
        }
        .padding()
        .background(Color(white: 0.15))
        .cornerRadius(12)
        // Add a subtle touch target expansion so users don't have to be perfectly precise
        .contentShape(Rectangle())
    }
    
    func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        let tenths = Int((interval.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
    
    func formatDelta(_ interval: TimeInterval) -> String {
        let sign = interval > 0 ? "+" : ""
        return String(format: "%@%.2f", sign, interval)
    }
}

// MARK: - EXISTING SUBVIEWS
struct DashboardStat: View {
    let title: String
    let value: String
    let unit: String
    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(.caption2).bold().foregroundStyle(.gray)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.system(size: 28, weight: .black, design: .rounded)).foregroundStyle(.white)
                Text(unit).font(.caption).bold().foregroundStyle(.red)
            }
        }
    }
}

struct LapTapeCard: View {
    let lapNumber: Int
    let duration: TimeInterval
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(lapNumber)")
                .font(.title2.bold())
                .foregroundStyle(isSelected ? .red : .white)
            Text(formatTime(duration))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isSelected ? .red : .gray)
        }
        .frame(width: 76, height: 76)
        .background(isSelected ? Color.white : Color(white: 0.15))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.red : Color.clear, lineWidth: 2)
        )
    }
    
    func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        let tenths = Int((interval.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}

// MARK: - PREVIEW
#Preview {
    let mockLaps = [
        DrivingTelemDataPoint.generateProceduralRallyLap(duration: 65, variance: 0.8, seed: 2),
        DrivingTelemDataPoint.generateProceduralRallyLap(duration: 62, variance: 0.4, seed: 1),
        DrivingTelemDataPoint.generateProceduralRallyLap(duration: 59, variance: 0.1, seed: 1),
        DrivingTelemDataPoint.generateProceduralRallyLap(duration: 61, variance: 0.3, seed: 1),
        DrivingTelemDataPoint.generateProceduralRallyLap(duration: 63, variance: 0.5, seed: 1)
    ]
    //in prod mock laps would be replaced by the returned array ofDrivingTelemDataPoint objects and returned in the same way
    return SessionSummaryView(laps: mockLaps).preferredColorScheme(.dark)
}
