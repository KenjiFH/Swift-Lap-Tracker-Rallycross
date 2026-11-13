//
//  Util.swift
//  Apexiel Proj1
//
//  Created by Kenji Fahselt on 3/3/26.
//

import Foundation



class SessionParser {
    
    /// Reads a single .jsonl file and converts it back into an array of Swift objects (One complete Lap)
    static func loadLapData(from url: URL) -> [DrivingTelemDataPoint] {
        var lapPoints: [DrivingTelemDataPoint] = []
        let decoder = JSONDecoder()
        
        do {
            let fileContents = try String(contentsOf: url, encoding: .utf8)
            let lines = fileContents.split(separator: "\n")
            
            for line in lines {
                // Ignore empty lines
                guard !line.isEmpty else { continue }
                
                if let data = line.data(using: .utf8),
                   let point = try? decoder.decode(DrivingTelemDataPoint.self, from: data) {
                    lapPoints.append(point)
                }
            }
        } catch {
            print("❌ Failed to read file at \(url.lastPathComponent): \(error)")
        }
        
        return lapPoints
    }
}
