//
//  MenuView.swift
//  Apexiel Proj1
//
//  Created by Kenji Fahselt on 3/13/26.
//




import SwiftUI


//this file includes all the main menu views as well as the splash screen and related elements

// THE ROOT TAB CONTROLLER
struct MainTabView: View {
    // Defines which tab is open by default. 0 is the Hub.
    @State private var selectedTab = 0
    
    // Set the dark mode styling for the tab bar globally
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            
            // TAB 0: Home Hub
            RallyHubView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Hub")
                }
                .tag(0)
            
            // TAB 1: Capture
            CaptureView()
                .tabItem {
                    Image(systemName: "video.fill")
                    Text("Capture")
                }
                .tag(1)
            
            // TAB 2: Vault / Heats
            HeatDashboardView() // Assuming this is the name of your existing dashboard
                .tabItem {
                    Image(systemName: "flag.checkered")
                    Text("Heats")
                }
                .tag(2)
        }
        // Tint the active tab icon with your brand red
        .tint(Color(red: 0.8, green: 0.2, blue: 0.2))
        .preferredColorScheme(.dark)
    }
}

// MARK: - 3. MODULAR HUB CARD
struct HubCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content
    
    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3).bold()
                .foregroundStyle(.white)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }
            
            // Injects whatever custom UI you pass into the block
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.15))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - 4. THE MAIN MENU (RALLY HUB)
struct RallyHubView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // CARD 1: Quick Start
                        HubCard(title: "Quick Start: Active Heat", subtitle: "Tap to begin logging immediately.") {
                            Button {
                                // Action to jump to CaptureView goes here
                                let impact = UIImpactFeedbackGenerator(style: .medium)
                                impact.impactOccurred()
                            } label: {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("START RECORDING (HEAT 1)")
                                        .fontWeight(.bold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(red: 0.8, green: 0.2, blue: 0.2)) // Deep Red
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                        }
                        
                        // CARD 2: Quick Links / Recent Heats
                        HubCard(title: "Recent Sessions", subtitle: "Jump straight to analysis.") {
                            VStack(spacing: 0) {
                                // Example mock data. You will hook this up to your ViewModel.
                                QuickLinkRow(title: "Finals", date: "Mar 10, 2:30 PM", dataString: "06 Laps | 3.2 Miles")
                                Divider().background(Color.gray.opacity(0.3))
                                QuickLinkRow(title: "Qualifying 2", date: "Mar 10, 1:15 PM", dataString: "04 Laps | 2.1 Miles")
                            }
                            .background(Color(white: 0.1))
                            .cornerRadius(10)
                        }
                        
                        // CARD 3: Season Totals (Future Extensibility)
                        HubCard(title: "Season Data Total") {
                            Text("284 Total Recorded Miles")
                                .font(.headline)
                                .foregroundStyle(.gray)
                        }
                        
                    }
                    .padding()
                }
            }
            .navigationTitle("Rally Hub")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

// Helper for the recent heats list
struct QuickLinkRow: View {
    let title: String
    let date: String
    let dataString: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(.white)
                Text("\(dataString) • \(date)").font(.caption).foregroundStyle(.gray)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.gray)
        }
        .padding()
    }
}


// MARK: - 1. THE LOGO SHAPE (Pure Math)
struct ApexielLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Mathematical approximation of the Apexiel Chevron with Arch
        let width = rect.width
        let height = rect.height
        let thickness = height * 0.35
        
        // Start bottom left
        path.move(to: CGPoint(x: 0, y: height))
        // Up to the top peak
        path.addLine(to: CGPoint(x: width / 2, y: 0))
        // Down to the bottom right
        path.addLine(to: CGPoint(x: width, y: height))
        
        // Inner curve (The Arch Cutout)
        path.addLine(to: CGPoint(x: width - (width * 0.15), y: height))
        // Draw the arch using a quadratic curve to the other side
        path.addQuadCurve(
            to: CGPoint(x: width * 0.15, y: height),
            control: CGPoint(x: width / 2, y: height - thickness)
        )
        
        path.closeSubpath()
        return path
    }
}

// MARK: - 2. THE SPLASH SCREEN
struct SplashScreenView: View {
    @State private var isActive = false
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0.0
    
    var body: some View {
        if isActive {
            // Once the timer finishes, show the actual app
            MainTabView()
        } else {
            ZStack {
                // Deep charcoal background
                Color.white
                    .ignoresSafeArea()
                
                VStack(spacing: 50) {
                    //svg instead
                    Image("apexiel_with_logo").resizable().scaledToFit()
                    /*
                    // The Pure Swift Logo
                    ApexielLogoShape()
                        .fill(Color(red: 0.8, green: 0.2, blue: 0.2)) // Deep Red
                        .frame(width: 160, height: 100)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                     */
                    
                    // Native iOS Loading Spinner tinted red
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.8, green: 0.2, blue: 0.2)))
                        .scaleEffect(1.5)
                        .opacity(logoOpacity)
                }
            }
            .onAppear {
                // 1. Animate the logo popping in
                withAnimation(.easeOut(duration: 0.8)) {
                    self.logoScale = 1.0
                    self.logoOpacity = 1.0
                }
                
                // 2. Wait 1.5 seconds, then transition to the main app
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        self.isActive = true
                    }
                }
            }
        }
    }
}
