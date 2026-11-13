//
//  LapModel.swift
//  Apexiel Proj1
//
//  Created by Kenji Fahselt on 11/4/25.
//

import Foundation
import UIKit
import CoreLocation
import MapKit
import SwiftUI

//LAPMODEL contains the logic for data ingestion from Lap data, as well as the rendering/zoning for the turn visuals

//lapmanager is repsonsible for housing all the laps from in memory or from the sd card, lapview needs to to
//display the laps from these sources

class LapManager: ObservableObject {
    @Published var laps: [Lap] = []
    @Published var currentLap: Lap?
    
    func startNewLap(color: UIColor) {
        if let lap = currentLap, !lap.coordinates.isEmpty {
            laps.append(lap)
        }
        currentLap = Lap(coordinates: [], color: color)
    }
    
    func addLocation(_ location: CLLocationCoordinate2D) {
        currentLap?.coordinates.append(location)
    }
}

//mapview is the overall view of the map section, it contains the UI
//logic for displaying turns and all the required helpers
struct MapViewLaps: UIViewRepresentable {
    @ObservedObject var lapManager: LapManager

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 1. Clear old overlays
        mapView.removeOverlays(mapView.overlays)
        
        for lap in lapManager.laps {
                let polyline = MKPolyline(coordinates: lap.coordinates, count: lap.coordinates.count)
                
                // IMPORTANT STEP: Tag the line with the ID so we can look it up later
                polyline.title = lap.id.uuidString
                
                mapView.addOverlay(polyline)
            }

        // 2. Add overlays (Existing Laps + Current Lap)
        var allPolylines: [MKPolyline] = []
        
        // Add completed laps
        for lap in lapManager.laps {
            let polyline = MKPolyline(coordinates: lap.coordinates, count: lap.coordinates.count)
            polyline.title = lap.id.uuidString
            allPolylines.append(polyline)
        }

        // Add current lap
        if let currentLap = lapManager.currentLap {
            let polyline = MKPolyline(coordinates: currentLap.coordinates, count: currentLap.coordinates.count)
            polyline.title = "current"
            allPolylines.append(polyline)
        }
        
        // Add everything to the map at once
        mapView.addOverlays(allPolylines)

        // 3. THE NEW LOGIC: Calculate the bounding box using MapKit
        // Start with a "null" rectangle (an invalid/empty rect)
        var zoomRect = MKMapRect.null
        
        for polyline in allPolylines {
            let rect = polyline.boundingMapRect
            
            if zoomRect.isNull {
                // If this is the first one, just take its rect
                zoomRect = rect
            } else {
                // Otherwise, combine (union) the existing rect with the new one
                zoomRect = zoomRect.union(rect)
            }
        }

        // 4. Apply the zoom
        // Only zoom if we have a valid rectangle (rect is not infinite or empty)
        if !zoomRect.isNull {
            // UIEdgeInsets gives you padding so the line isn't touching the edge of the screen
            let padding = UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50)
            mapView.setVisibleMapRect(zoomRect, edgePadding: padding, animated: true)
        }
    }

    // MARK: - Bounding region helper
    private func regionThatFits(_ coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard !coordinates.isEmpty else { return nil }

        var minLat = coordinates.first!.latitude
        var maxLat = coordinates.first!.latitude
        var minLon = coordinates.first!.longitude
        var maxLon = coordinates.first!.longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let latDelta = (maxLat - minLat) * 1.4
        let lonDelta = (maxLon - minLon) * 1.4

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(MapViewLaps(lapManager: lapManager))
    }
    
    //pattern to delegate methods to coordinator, used in lifecycle updates
    //in this case its rendering laps
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewLaps // Access to the parent view (and the data manager)

        init(_ parent: MapViewLaps) {
            self.parent = parent
        }
        //TODO, add dropdown to see diff laps
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else { return MKOverlayRenderer() }
            let renderer = MKPolylineRenderer(polyline: polyline)

            // 1. Get the ID we tagged earlier
            if let lapIDString = polyline.title,
               let lapUUID = UUID(uuidString: lapIDString) {
                
                // 2. SEARCH the manager's data for the matching Lap
                // This logic bridges the gap between the map line and your extension data
                if let matchingLap = parent.lapManager.laps.first(where: { $0.id == lapUUID }) {
                    
                    // 3. APPLY the color found in the model
                    renderer.strokeColor = matchingLap.color
                }
            }
            
            // Fallback for current lap or if lookup fails
            if renderer.strokeColor == nil {
                renderer.strokeColor = .gray
            }

            renderer.lineWidth = 5
            return renderer
        }
    }
}

//Mock lap manager class which ingests the extension laps from Lap.swift for testing and visualizing purposes
class MockLapManager: LapManager {
    override init() {
        super.init()
        self.laps = Lap.mockLaps
        self.currentLap = Lap(coordinates: [], color: .red)
    }
}

