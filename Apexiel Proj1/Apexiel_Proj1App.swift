//
//  Apexiel_Proj1App.swift
//  Apexiel Proj1
//
//  Created by Kenji Fahselt on 7/13/25.
//

import SwiftUI
import FirebaseCore




@main
struct Apexiel_Proj1App: App {
    
    // NEW: Initialize Firebase when the app struct is created
        init() {
            FirebaseApp.configure()
            print("🔥 Firebase Cloud Layer Initialized")
        }
    var body: some Scene {
        WindowGroup {
            //ContentView()
            //DrivingView()
            // This is the absolute starting point of your app
                        SplashScreenView()
                            // Enforce dark mode globally so the splash screen perfectly matches the Hub
                            .preferredColorScheme(.dark)

        }
    }
}


struct FirstMainTabView: View {
    var body: some View {
        TabView {
            CaptureView()       // stats
                .tabItem {
                    Label("Capture Data", systemImage: "car.fill")
                }
            HeatDashboardView()
                .tabItem {
                    Label("View Heat Dashboard", systemImage:"list.bullet.rectangle")
                }
            
        }
    }
    
}
