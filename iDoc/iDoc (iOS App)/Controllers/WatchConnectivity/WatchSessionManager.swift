//
//  WatchSessionManager.swift
//  iDoc
//
//  Created by Keith  Salyer on 2/24/25.
//

import WatchConnectivity
import Foundation
import Combine

class WatchSessionManager: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = WatchSessionManager()
    
    @Published var latestHeartRate: Double = 0.0
    @Published var lastUpdateTime: Date?
    @Published var activationState: WCSessionActivationState = .notActivated
    @Published var isReachable: Bool = false
    @Published var connectionStatus: String = "Not Connected"
    @Published var dataSource: String = "None" // Track which source provided the data
    @Published var isWatchWorn: Bool = true // Track if the watch is being worn
    @Published var wornState: String = "Worn" // Human-readable worn state
    
    override init() {
        super.init()
        print("Initializing WatchSessionManager on iOS")
        if WCSession.isSupported() {
            print("WCSession is supported on iOS, setting delegate")
            let session = WCSession.default
            session.delegate = self
            print("Activating WCSession on iOS...")
            session.activate()
        } else {
            print("WCSession is not supported on this iOS device")
        }
    }
    
    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.activationState = activationState
            self.isReachable = session.isReachable
            
            switch activationState {
            case .activated:
                self.connectionStatus = "Connected"
            case .inactive:
                self.connectionStatus = "Inactive"
            case .notActivated:
                self.connectionStatus = "Not Activated"
            @unknown default:
                self.connectionStatus = "Unknown State"
            }
        }
        
        if let error = error {
            print("WCSession activation error on iOS: \(error.localizedDescription)")
        } else {
            print("WCSession activated on iOS with state: \(activationState.rawValue)")
            print("WCSession isPaired: \(session.isPaired)")
            print("WCSession isWatchAppInstalled: \(session.isWatchAppInstalled)")
            print("WCSession isComplicationEnabled: \(session.isComplicationEnabled)")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("iOS received message: \(message)")
        
        // Check if this is a worn state update
        if let isWorn = message["isWorn"] as? Bool {
            DispatchQueue.main.async {
                self.isWatchWorn = isWorn
                self.wornState = message["wornState"] as? String ?? (isWorn ? "Worn" : "Not Worn")
                
                // Update connection status to show worn state
                if !isWorn {
                    self.connectionStatus = "Watch Not Worn"
                }
            }
        }
        
        // Check if this is a heart rate update
        if let heartRate = message["heartRate"] as? Double {
            // Get timestamp if available, otherwise use current time
            let timestamp: Date
            if let timeInterval = message["timestamp"] as? TimeInterval {
                timestamp = Date(timeIntervalSince1970: timeInterval)
            } else {
                timestamp = Date()
            }
            
            // Get data source if available
            let source = message["source"] as? String ?? "Unknown"
            
            // Get worn state if available
            let isWorn = message["isWorn"] as? Bool ?? true
            
            print("iOS: Received heart rate: \(heartRate) BPM from \(source) at \(formatDate(timestamp)), worn: \(isWorn)")
            
            DispatchQueue.main.async {
                // Only update heart rate if the watch is being worn
                if isWorn {
                    self.latestHeartRate = heartRate
                    self.lastUpdateTime = timestamp
                    self.dataSource = source
                    self.isWatchWorn = isWorn
                    self.isReachable = session.isReachable
                    self.connectionStatus = "Connected - \(source) data"
                } else {
                    // Update worn state but don't update heart rate
                    self.isWatchWorn = false
                    self.wornState = "Not Worn"
                    self.connectionStatus = "Watch Not Worn"
                }
            }
        } else if message["heartRate"] == nil && message["isWorn"] == nil {
            print("iOS: Received message without valid data: \(message)")
        }
    }
    
    // Format date for consistent logging
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
    
    // Handle application context updates
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("iOS: Received application context: \(applicationContext)")
        if let heartRate = applicationContext["heartRate"] as? Double {
            print("iOS: Received heart rate from context: \(heartRate) BPM")
            DispatchQueue.main.async {
                self.latestHeartRate = heartRate
            }
        }
    }
    
    // For iOS 13+ these stubs can remain empty:
    func sessionDidBecomeInactive(_ session: WCSession) { }
    func sessionDidDeactivate(_ session: WCSession) { }
}
