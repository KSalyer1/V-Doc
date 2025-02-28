//
//  ContentView.swift
//  iDoc
//
//  Created by Keith  Salyer on 2/24/25.
//

import SwiftUI
import WatchConnectivity
import WatchKit

struct ContentView: View {
    @EnvironmentObject var healthManager: WatchHealthManager

    var body: some View {
        VStack(spacing: 6) {
            // Heart rate display
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(healthManager.isBeingWorn ? .red : .gray)
                Text(healthManager.currentBPM > 0 ? "\(Int(healthManager.currentBPM))" : "--")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(healthManager.isBeingWorn ? .primary : .gray)
                Text("BPM")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
            
            // Authorization status
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(healthManager.authorizationStatus)
                    .font(.system(size: 10))
                    .foregroundColor(statusColor)
            }
            
            // Debug state and motion info (only in debug builds)
            #if DEBUG
            VStack(spacing: 2) {
                Text(healthManager.debugState)
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
                
                // Motion level and confidence
                Text("Motion: \(String(format: "%.3f", healthManager.motionLevel)) | Conf: \(healthManager.confidenceLevel)%")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
            }
            #endif
            
            // Error message if any
            if !healthManager.errorMessage.isEmpty {
                Text(healthManager.errorMessage)
                    .font(.system(size: 9))
                    .foregroundColor(.red)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 4)
            }
            
            // Worn state indicator with animation
            HStack {
                Circle()
                    .fill(healthManager.isBeingWorn ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: healthManager.isBeingWorn)
                Text(healthManager.wornState)
                    .font(.system(size: 10))
                    .foregroundColor(healthManager.isBeingWorn ? .green : .red)
                    .animation(.easeInOut(duration: 0.3), value: healthManager.isBeingWorn)
            }
            
            // Not worn message - only show when not worn
            if !healthManager.isBeingWorn {
                Text("Please wear watch to monitor heart rate")
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 4)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.5), value: healthManager.isBeingWorn)
            }
            
            // Heart rate source and timestamp
            if let lastUpdate = healthManager.lastUpdateTime {
                VStack(spacing: 2) {
                    Text("Source: \(healthManager.dataSource)")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                    
                    Text("Updated: \(formatTime(lastUpdate))")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                }
            }
            
            // Button row
            VStack(spacing: 6) {
                // Authorization button - only show if not authorized
                if healthManager.authorizationStatus != "Authorized" {
                    Button(action: {
                        print("Requesting explicit HealthKit authorization")
                        // Clear UserDefaults to force a fresh check
                        UserDefaults.standard.removeObject(forKey: "HealthKitAuthorizationStatus")
                        healthManager.requestHealthKitAuthorization()
                    }) {
                        Text("1. Allow Health Access")
                            .font(.system(size: 10))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                
                // Force Start button - show when not monitoring
                if !healthManager.isMonitoring {
                    Button(action: {
                        print("Force starting heart rate monitoring")
                        healthManager.forceStartMonitoring()
                    }) {
                        Text("2. Force Start")
                            .font(.system(size: 10))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                
                HStack(spacing: 4) {
                    // Real-time button
                    Button(action: {
                        print("Starting real-time monitoring")
                        healthManager.startRealTimeMonitoring()
                    }) {
                        Text("Real-time")
                            .font(.system(size: 9))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    
                    // Periodic Updates button
                    Button(action: {
                        print("Starting periodic heart rate updates")
                        healthManager.startPeriodicHeartRateUpdates()
                    }) {
                        Text("Periodic")
                            .font(.system(size: 9))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                
                // Settings button - only show if access is denied
                if healthManager.authorizationStatus == "Access Denied" {
                    Button(action: {
                        // This will open the Health app
                        WKExtension.shared().openSystemURL(URL(string: "x-apple-health://")!)
                    }) {
                        Text("Open Health App")
                            .font(.system(size: 10))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
            }
        }
        .onAppear {
            print("ContentView appeared - starting heart rate updates")
            healthManager.startHeartRateMonitoring()
        }
    }
    
    // Format time for display
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
    
    // Color based on authorization status
    private var statusColor: Color {
        switch healthManager.authorizationStatus {
        case "Authorized":
            return .green
        case "Not Determined":
            return .yellow
        case "Authorization Failed", "Access Denied":
            return .red
        default:
            return .orange
        }
    }
}
