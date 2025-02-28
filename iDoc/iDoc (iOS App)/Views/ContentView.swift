//
//  ContentView.swift
//  iDoc
//
//  Created by Keith  Salyer on 2/24/25.
//

import SwiftUI
import WatchConnectivity

struct ContentView: View {
    @State private var showVitals = false
    @ObservedObject private var watchSession = WatchSessionManager.shared
    
    var body: some View {
        ZStack {
            // AR camera feed in the background
            ARViewContainer()
                .edgesIgnoringSafeArea(.all)
            
            // Conditionally overlay the vitals panel (no background color)
            if showVitals {
                VStack {
                    Spacer()
                    VitalsPanelRepresentable()
                        .frame(height: 100)
                        .cornerRadius(12)
                        .padding()
                }
                .transition(.move(edge: .bottom))
            }
            
            // Controls and status
            VStack {
                // Watch connection status
                HStack {
                    Circle()
                        .fill(watchSession.isReachable ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(watchSession.connectionStatus)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                Spacer()
                
                // Buttons row
                HStack {
                    // Debug button
                    Button(action: {
                        print("iOS Debug: WCSession isReachable = \(watchSession.isReachable)")
                        print("iOS Debug: WCSession activation state = \(watchSession.activationState.rawValue)")
                        print("iOS Debug: WCSession isPaired = \(WCSession.default.isPaired)")
                        print("iOS Debug: WCSession isWatchAppInstalled = \(WCSession.default.isWatchAppInstalled)")
                        print("iOS Debug: Current heart rate = \(watchSession.latestHeartRate)")
                        
                        // Force WCSession activation if not activated
                        if watchSession.activationState != .activated {
                            print("Attempting to reactivate WCSession...")
                            WCSession.default.activate()
                        }
                    }) {
                        Text("Debug")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red.opacity(0.7))
                            .cornerRadius(10)
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Toggle vitals button
                    Button(action: {
                        showVitals.toggle()
                        print("Toggle vitals: \(showVitals)")
                    }) {
                        Text(showVitals ? "Hide Vitals" : "Show Vitals")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue.opacity(0.7))
                            .cornerRadius(10)
                    }
                    .padding()
                }
                
                // Last update time
                if let lastUpdate = watchSession.lastUpdateTime {
                    HStack {
                        Text("Last update: \(timeAgoString(from: lastUpdate))")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .padding(.bottom, 4)
                        Spacer()
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // Helper function to format time ago
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
