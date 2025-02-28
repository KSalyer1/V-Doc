//
//  LiveBPMView.swift
//  iDoc
//
//  Created by Keith  Salyer on 2/24/25.
//

import SwiftUI

struct LiveBPMView: View {
    @EnvironmentObject var healthManager: WatchHealthManager
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Live Heart Rate")
                .font(.headline)
            
            Text(healthManager.currentBPM > 0 ? "\(Int(healthManager.currentBPM)) BPM" : "-- BPM")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(healthManager.isBeingWorn ? .red : .gray)
            
            // Worn state indicator
            HStack {
                Circle()
                    .fill(healthManager.isBeingWorn ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(healthManager.wornState)
                    .font(.caption2)
                    .foregroundColor(healthManager.isBeingWorn ? .green : .red)
            }
            
            // Not worn message
            if !healthManager.isBeingWorn {
                Text("Please wear watch to monitor heart rate")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
            }
            
            // Data source and timestamp
            if let lastUpdate = healthManager.lastUpdateTime, healthManager.isBeingWorn {
                VStack(spacing: 2) {
                    Text("Source: \(healthManager.dataSource)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Text("Updated: \(formatTime(lastUpdate))")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            HStack(spacing: 8) {
                // Real-time button
                Button(action: {
                    healthManager.startRealTimeMonitoring()
                }) {
                    Text("Real-time")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                // Historical button
                Button(action: {
                    healthManager.startHeartRateMonitoring()
                }) {
                    Text("Historical")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            
            HStack(spacing: 8) {
                // Periodic button
                Button(action: {
                    healthManager.startPeriodicHeartRateUpdates()
                }) {
                    Text("Periodic")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                // Stop button
                Button(action: {
                    healthManager.stopHeartRateMonitoring()
                    healthManager.stopRealTimeMonitoring()
                }) {
                    Text("Stop")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .onAppear {
            // Start both monitoring approaches for best results
            healthManager.startHeartRateMonitoring()
            healthManager.startRealTimeMonitoring()
            healthManager.startPeriodicHeartRateUpdates()
        }
    }
    
    // Format time for display
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}
