//
//  TelemetryTestView.swift
//  Apexiel Proj1
//
//  Created by Kenji Fahselt on 1/28/26.
//

import SwiftUI
import Charts
import MapKit

struct TelemetryTestView: View {
    //TODO should be dist over time use point.totalDistance
    //first we need to make it gen different laps though since4
    //THIS generates the same lap every time
    // 1. Generate Data on Init
    let lapData = DrivingTelemDataPoint.generateMockLap(duration: 45)
    
    // Comparison Lap (Slightly modified for fun)
    let comparisonLap = DrivingTelemDataPoint.generateMockLapVariant(duration: 48)
    
    
    
    var chartData: [(id: String, color: Color, data: [DrivingTelemDataPoint])] {
        [
            (id: "Reference", color: .blue, data: lapData),
            (id: "Comparison", color: .red, data: comparisonLap)
        ]
    }
    
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Header
                VStack(alignment: .leading) {
                    Text("Telemetry Debugger")
                        .font(.largeTitle.bold())
                    Text("\(lapData.count) Data Points Generated")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                // VISUAL 1: Speed Trace Chart
                VStack(alignment: .leading) {
                    Text("Speed Trace (m/s)")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Chart {
                        // 1. Loop through the *Series* (the two laps)
                        ForEach(chartData, id: \.id) { series in
                            
                            // 2. Loop through the *Points* in that series
                            ForEach(series.data) { point in
                                LineMark(
                                    x: .value("Time", point.timestamp),
                                    y: .value("Speed", point.speed)
                                )
                            }
                            .foregroundStyle(by: .value("Speed", series.id))
                            .interpolationMethod(.catmullRom)
                         
                            .lineStyle(series.id == "Reference" ? StrokeStyle(lineWidth: 1, dash: [5]) : StrokeStyle(lineWidth: 2))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .frame(height: 250)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .padding(.horizontal)


                
                // VISUAL 2: Mini Map (Canvas)
                // Using Canvas is faster for drawing 1000s of points than Map()
                VStack(alignment: .leading) {
                    Text("GPS Track Plot")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    GeometryReader { geo in
                        Canvas { context, size in
                            // Simple normalization logic to fit coords in box
                            let lats = lapData.map { $0.coordinate.latitude }
                            let lons = lapData.map { $0.coordinate.longitude }
                            
                            guard let minLat = lats.min(), let maxLat = lats.max(),
                                  let minLon = lons.min(), let maxLon = lons.max() else { return }
                            
                            let latSpan = maxLat - minLat
                            let lonSpan = maxLon - minLon
                            
                            var path = Path()
                            
                            for (index, point) in lapData.enumerated() {
                                let x = ((point.coordinate.longitude - minLon) / lonSpan) * size.width
                                let y = ((point.coordinate.latitude - minLat) / latSpan) * size.height
                                
                                // Invert Y because screen Y goes down
                                let fixedY = size.height - y
                                
                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: fixedY))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: fixedY))
                                }
                            }
                            
                            context.stroke(path, with: .color(.green), lineWidth: 3)
                        }
                    }
                    .frame(height: 250)
                    .background(Color.black)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

// Preview
#Preview {
    TelemetryTestView()
        .preferredColorScheme(.dark)
}
