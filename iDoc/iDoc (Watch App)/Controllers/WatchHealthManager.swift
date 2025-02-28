//
//  WatchHealthManager.swift
//  iDoc
//
//  Created by Keith  Salyer on 2/24/25.
//

import Foundation
import HealthKit
import WatchConnectivity
import CoreMotion
import WatchKit

class WatchHealthManager: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    
    private lazy var healthStore = HKHealthStore()
    // Observer query approach
    private var heartRateQuery: HKObserverQuery?
    private var heartRateSampleQuery: HKSampleQuery?
    private var heartRateObserver: Any?
    // Workout session approach for real-time data
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    // Timer for frequent updates
    private var updateTimer: Timer?
    // State tracking
    private var isCheckingAuthorization = false
    private var authorizationRetryCount = 0
    private let maxAuthorizationRetries = 3
    
    // Motion manager for detecting if watch is being worn
    private let motionManager = CMMotionManager()
    private var motionTimer: Timer?
    private var wornStateTimer: Timer?
    private var lastSignificantMotionTime: Date?
    
    // Improved motion detection parameters
    private let motionThreshold: Double = 0.08 // Increased threshold to avoid false positives
    private let unwornTimeThreshold: TimeInterval = 45.0 // Longer time to detect unworn state
    private var wornConfidence: Int = 100 // Confidence level (0-100)
    private let confidenceThreshold: Int = 50 // Threshold to change worn state
    private var recentMotionValues: [Double] = [] // Store recent motion values
    private let maxRecentMotionValues = 10 // Number of recent values to store
    private var lastWornStateChangeTime: Date = Date() // Track last state change
    private let minStateChangeInterval: TimeInterval = 30.0 // Minimum time between state changes
    
    @Published var currentBPM: Double = 0.0
    @Published var lastUpdateTime: Date?
    @Published var isMonitoring: Bool = false
    @Published var authorizationStatus: String = "Not Determined"
    @Published var errorMessage: String = ""
    @Published var debugState: String = "Initializing"
    @Published var dataSource: String = "None" // Track which source provided the data
    @Published var isBeingWorn: Bool = true // Track if the watch is being worn
    @Published var wornState: String = "Worn" // Human-readable worn state
    @Published var motionLevel: Double = 0.0 // Current motion level for debugging
    @Published var confidenceLevel: Int = 100 // Public confidence level for UI

    // Keys for UserDefaults
    private let authStatusKey = "HealthKitAuthorizationStatus"
    
    override init() {
        super.init()
        
        // Load saved authorization status if available
        if let savedStatus = UserDefaults.standard.string(forKey: authStatusKey) {
            print("Loading saved authorization status: \(savedStatus)")
            self.authorizationStatus = savedStatus
        }
        
        // Check if HealthKit is available on this device
        if !HKHealthStore.isHealthDataAvailable() {
            self.authorizationStatus = "Not Available"
            self.errorMessage = "HealthKit is not available on this device"
            return
        }
        
        // Start motion detection to determine if watch is being worn
        startMotionDetection()
        
        // Request authorization with a delay to allow UI to load first
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.requestHealthKitAuthorization()
        }
    }
    
    deinit {
        // Clean up any observers
        if let observer = heartRateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // Stop any active queries
        if let query = heartRateQuery {
            healthStore.stop(query)
        }
        
        // Stop any active workout sessions
        stopRealTimeMonitoring()
        
        // Stop any timers
        updateTimer?.invalidate()
        motionTimer?.invalidate()
        wornStateTimer?.invalidate()
        
        // Stop motion manager
        motionManager.stopAccelerometerUpdates()
        motionManager.stopDeviceMotionUpdates()
    }
    
    // MARK: - Wrist Detection Methods
    
    private func startMotionDetection() {
        // Check if accelerometer is available
        guard motionManager.isAccelerometerAvailable else {
            print("Accelerometer not available")
            return
        }
        
        // Set up device motion (combines accelerometer and gyroscope)
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.5
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
                guard let self = self, let motion = motion else { return }
                
                // Calculate total acceleration magnitude (removing gravity)
                let userAccel = motion.userAcceleration
                let magnitude = sqrt(pow(userAccel.x, 2) + 
                                    pow(userAccel.y, 2) + 
                                    pow(userAccel.z, 2))
                
                // Store for rolling average
                self.addMotionReading(magnitude)
                
                // Update motion level for debugging
                DispatchQueue.main.async {
                    self.motionLevel = magnitude
                }
                
                // Check if there's significant motion
                let significantMotion = magnitude > self.motionThreshold
                
                if significantMotion {
                    self.lastSignificantMotionTime = Date()
                    
                    // Increase confidence that watch is being worn
                    self.adjustWornConfidence(by: 10)
                    
                    print("Motion detected: \(magnitude) (confidence: \(self.wornConfidence))")
                } else {
                    // Slightly decrease confidence if no motion
                    self.adjustWornConfidence(by: -1)
                }
                
                // Check if we should update the worn state
                self.evaluateWornState()
            }
        } else {
            // Fallback to just accelerometer if device motion not available
            motionManager.accelerometerUpdateInterval = 0.5
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] (data, error) in
                guard let self = self, let data = data else { return }
                
                // Calculate total acceleration magnitude
                let magnitude = sqrt(pow(data.acceleration.x, 2) + 
                                    pow(data.acceleration.y, 2) + 
                                    pow(data.acceleration.z, 2))
                
                // Remove gravity component (approximate)
                let motionMagnitude = abs(magnitude - 1.0)
                
                // Store for rolling average
                self.addMotionReading(motionMagnitude)
                
                // Update motion level for debugging
                DispatchQueue.main.async {
                    self.motionLevel = motionMagnitude
                }
                
                // Check if there's significant motion
                let significantMotion = motionMagnitude > self.motionThreshold
                
                if significantMotion {
                    self.lastSignificantMotionTime = Date()
                    
                    // Increase confidence that watch is being worn
                    self.adjustWornConfidence(by: 10)
                    
                    print("Motion detected: \(motionMagnitude) (confidence: \(self.wornConfidence))")
                } else {
                    // Slightly decrease confidence if no motion
                    self.adjustWornConfidence(by: -1)
                }
                
                // Check if we should update the worn state
                self.evaluateWornState()
            }
        }
        
        // Set up timer to periodically check for lack of motion
        motionTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Check if there's been no significant motion for the threshold time
            if let lastMotion = self.lastSignificantMotionTime {
                let timeSinceMotion = Date().timeIntervalSince(lastMotion)
                
                // If no motion for threshold time, decrease confidence significantly
                if timeSinceMotion > self.unwornTimeThreshold {
                    // Decrease confidence more the longer we go without motion
                    let confidenceDecrease = min(50, Int(timeSinceMotion / 10.0))
                    self.adjustWornConfidence(by: -confidenceDecrease)
                    
                    print("No motion for \(Int(timeSinceMotion))s - decreasing confidence by \(confidenceDecrease) to \(self.wornConfidence)")
                    
                    // Check if we should update the worn state
                    self.evaluateWornState()
                }
            } else {
                // Initialize if nil
                self.lastSignificantMotionTime = Date()
            }
            
            // Check wrist detection from WKInterfaceDevice if available
            self.checkWristDetection()
        }
        
        // Set up a separate timer to periodically send worn state updates
        wornStateTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Send the current worn state to the iPhone
            WatchConnectivityService.shared.sendMessage([
                "isWorn": self.isBeingWorn,
                "wornState": self.wornState,
                "timestamp": Date().timeIntervalSince1970,
                "confidence": self.confidenceLevel,
                "motionLevel": self.motionLevel
            ])
            
            print("Sent worn state update: \(self.isBeingWorn ? "Worn" : "Not Worn") (confidence: \(self.wornConfidence))")
        }
    }
    
    // Add a motion reading to the recent values array
    private func addMotionReading(_ value: Double) {
        recentMotionValues.append(value)
        if recentMotionValues.count > maxRecentMotionValues {
            recentMotionValues.removeFirst()
        }
    }
    
    // Get the average of recent motion values
    private func getAverageMotion() -> Double {
        guard !recentMotionValues.isEmpty else { return 0.0 }
        let sum = recentMotionValues.reduce(0.0, +)
        return sum / Double(recentMotionValues.count)
    }
    
    // Adjust the worn confidence level
    private func adjustWornConfidence(by amount: Int) {
        wornConfidence += amount
        
        // Clamp to 0-100 range
        wornConfidence = max(0, min(100, wornConfidence))
        
        // Update the public property
        DispatchQueue.main.async {
            self.confidenceLevel = self.wornConfidence
        }
    }
    
    // Check wrist detection from WKInterfaceDevice
    private func checkWristDetection() {
        // Check crown orientation to help determine if watch is being worn
        let crownOrientation = WKInterfaceDevice.current().crownOrientation
        
        // If crown orientation is left, it's more likely the watch is off the wrist
        if crownOrientation == .left {
            // Decrease confidence slightly
            adjustWornConfidence(by: -5)
            print("Crown orientation suggests unworn - decreasing confidence to \(wornConfidence)")
        }
        
        // Check if we have a heart rate - having a valid heart rate increases confidence
        if currentBPM > 40 && currentBPM < 200 {
            adjustWornConfidence(by: 5)
            print("Valid heart rate detected - increasing confidence to \(wornConfidence)")
        }
    }
    
    // Evaluate if we should change the worn state based on confidence
    private func evaluateWornState() {
        let timeSinceLastChange = Date().timeIntervalSince(lastWornStateChangeTime)
        
        // Only allow state changes after minimum interval
        guard timeSinceLastChange >= minStateChangeInterval else {
            return
        }
        
        if isBeingWorn && wornConfidence < confidenceThreshold {
            // Switch to not worn if confidence drops below threshold
            updateWornState(false)
            lastWornStateChangeTime = Date()
            print("Switching to NOT WORN state (confidence: \(wornConfidence))")
        } else if !isBeingWorn && wornConfidence > confidenceThreshold {
            // Switch to worn if confidence rises above threshold
            updateWornState(true)
            lastWornStateChangeTime = Date()
            print("Switching to WORN state (confidence: \(wornConfidence))")
        }
    }
    
    // Update worn state and notify observers
    private func updateWornState(_ isWorn: Bool) {
        DispatchQueue.main.async {
            self.isBeingWorn = isWorn
            self.wornState = isWorn ? "Worn" : "Not Worn"
            
            // If not worn, reset the current BPM to 0 to display as "--"
            if !isWorn {
                self.currentBPM = 0
            }
            
            // Send immediate update to iPhone
            WatchConnectivityService.shared.sendMessage([
                "isWorn": isWorn,
                "wornState": self.wornState,
                "timestamp": Date().timeIntervalSince1970,
                "confidence": self.confidenceLevel,
                "motionLevel": self.motionLevel
            ])
        }
    }
    
    private func saveAuthorizationStatus() {
        UserDefaults.standard.set(authorizationStatus, forKey: authStatusKey)
        print("Saved authorization status: \(authorizationStatus)")
    }
    
    // Format date for consistent logging
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
    
    // Decide whether to update heart rate based on source and timestamp
    private func shouldUpdateHeartRate(newValue: Double, source: String) -> Bool {
        // Always update if we have no data yet
        if currentBPM == 0 {
            return true
        }
        
        // Always update if this is real-time data
        if source == "Real-time" {
            return true
        }
        
        // For historical data, only update if it's non-zero
        return newValue > 0
    }
    
    // Update heart rate from any source
    private func updateHeartRate(_ value: Double, source: String, timestamp: Date) {
        // Only update if the watch is being worn or if this is historical data
        if isBeingWorn || source == "Historical" {
            DispatchQueue.main.async {
                self.currentBPM = value
                self.lastUpdateTime = timestamp
                self.dataSource = source
            }
            
            // Send to iPhone
            WatchConnectivityService.shared.sendMessage([
                "heartRate": value,
                "timestamp": timestamp.timeIntervalSince1970,
                "source": source,
                "isWorn": isBeingWorn,
                "confidence": confidenceLevel,
                "motionLevel": motionLevel
            ])
            
            print("Updated heart rate: \(value) BPM from \(source) at \(formatDate(timestamp))")
            
            // Clear any error message
            DispatchQueue.main.async {
                self.errorMessage = ""
                
                // Update authorization status if we successfully got data
                self.authorizationStatus = "Authorized"
                self.saveAuthorizationStatus()
            }
            
            // Getting a valid heart rate increases worn confidence
            if value > 40 && value < 200 {
                adjustWornConfidence(by: 5)
            }
        } else {
            print("Ignoring heart rate update - watch is not being worn")
            
            // Send a "not worn" status to iPhone with 0 BPM to display as "--"
            WatchConnectivityService.shared.sendMessage([
                "isWorn": false,
                "wornState": "Not Worn",
                "heartRate": 0.0,
                "timestamp": Date().timeIntervalSince1970,
                "source": source,
                "confidence": confidenceLevel,
                "motionLevel": motionLevel
            ])
            
            // Reset the current BPM to 0 to display as "--"
            DispatchQueue.main.async {
                self.currentBPM = 0
            }
        }
    }
    
    // Public method to explicitly request authorization when user taps button
    func requestHealthKitAuthorization() {
        // Reset retry count for explicit requests
        authorizationRetryCount = 0
        
        // Clear any saved status to force a fresh check
        UserDefaults.standard.removeObject(forKey: authStatusKey)
        
        debugState = "Requesting Auth"
        print("Requesting HealthKit authorization...")
        self.errorMessage = "Requesting permissions..."
        
        let typesToShare: Set<HKSampleType> = []
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { [weak self] success, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if success {
                    print("HealthKit authorization granted")
                    self.authorizationStatus = "Authorized"
                    self.errorMessage = "Authorization successful!"
                    self.saveAuthorizationStatus()
                    
                    // Wait longer before starting monitoring (5 seconds)
                    // This longer delay is crucial for watchOS to properly register the permission
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        self.debugState = "Starting after auth delay"
                        // Start both monitoring approaches
                        self.startHeartRateMonitoring()
                        self.startRealTimeMonitoring()
                    }
                } else {
                    let errorMsg = error?.localizedDescription ?? "Unknown error"
                    print("HealthKit authorization failed: \(errorMsg)")
                    self.authorizationStatus = "Authorization Failed"
                    self.saveAuthorizationStatus()
                    
                    if errorMsg.contains("denied") {
                        self.errorMessage = "Permission denied. Open Health app > Sources > iDoc > Turn on all categories."
                    } else {
                        self.errorMessage = "Error: \(errorMsg)"
                    }
                    
                    // Try to start monitoring anyway after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.debugState = "Trying anyway after auth failure"
                        self.startHeartRateMonitoring()
                        self.startRealTimeMonitoring()
                    }
                }
            }
        }
    }
    
    // Force start monitoring regardless of authorization status
    func forceStartMonitoring() {
        debugState = "Force Starting"
        self.errorMessage = "Attempting force start..."
        
        // Skip the authorization check and try to start monitoring directly
        startHeartRateMonitoring()
        startRealTimeMonitoring()
        startPeriodicHeartRateUpdates()
        
        // Reset worn confidence to high
        wornConfidence = 100
        DispatchQueue.main.async {
            self.confidenceLevel = 100
        }
        updateWornState(true)
    }
    
    // MARK: - Observer Query Methods
    
    func startHeartRateMonitoring() {
        debugState = "Starting Heart Rate Monitoring"
        
        // Stop any existing queries
        stopHeartRateMonitoring()
        
        // Get the heart rate quantity type
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            self.errorMessage = "Heart Rate Type Not Available"
            return
        }
        
        // Set up a predicate for the query - only get samples from the last hour
        let oneHourAgo = Date().addingTimeInterval(-3600)
        let predicate = HKQuery.predicateForSamples(withStart: oneHourAgo, end: nil, options: .strictEndDate)
        
        // Set up the observer query
        heartRateQuery = HKObserverQuery(sampleType: heartRateType, predicate: predicate) { [weak self] (query, completionHandler, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Heart rate observer query error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMessage = "Observer error: \(error.localizedDescription)"
                }
                completionHandler()
                return
            }
            
            // Fetch the latest heart rate sample
            self.fetchLatestHeartRateSample()
            
            // Call the completion handler
            completionHandler()
        }
        
        // Execute the query
        if let query = heartRateQuery {
            print("Starting heart rate observer query")
            healthStore.execute(query)
            
            // Enable background delivery if available
            healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .immediate) { (success, error) in
                if let error = error {
                    print("Failed to enable background delivery: \(error.localizedDescription)")
                } else if success {
                    print("Background delivery enabled successfully")
                }
            }
            
            // Set up a notification observer for when the app becomes active
            heartRateObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.NSExtensionHostDidBecomeActive, object: nil, queue: nil) { [weak self] _ in
                self?.fetchLatestHeartRateSample()
            }
            
            // Fetch the initial heart rate sample
            fetchLatestHeartRateSample()
            
            DispatchQueue.main.async {
                self.isMonitoring = true
                self.debugState = "Monitoring Active"
            }
        }
    }
    
    func stopHeartRateMonitoring() {
        debugState = "Stopping Monitoring"
        
        // Stop the observer query
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
        
        // Remove the notification observer
        if let observer = heartRateObserver {
            NotificationCenter.default.removeObserver(observer)
            heartRateObserver = nil
        }
        
        DispatchQueue.main.async {
            self.isMonitoring = false
        }
    }
    
    private func fetchLatestHeartRateSample() {
        // If the watch is not being worn, don't fetch heart rate
        if !isBeingWorn {
            print("Not fetching heart rate - watch is not being worn")
            return
        }
        
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        // Set up the sort descriptor to get the most recent sample
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        // Only get samples from the last hour
        let oneHourAgo = Date().addingTimeInterval(-3600)
        let predicate = HKQuery.predicateForSamples(withStart: oneHourAgo, end: nil, options: .strictEndDate)
        
        // Set up the query
        let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] (query, samples, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Heart rate sample query error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMessage = "Sample query error: \(error.localizedDescription)"
                }
                return
            }
            
            guard let samples = samples, let sample = samples.first as? HKQuantitySample else {
                print("No heart rate samples available")
                return
            }
            
            // Get the heart rate value
            let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
            let bpmValue = sample.quantity.doubleValue(for: heartRateUnit)
            
            print("Fetched historical heart rate: \(bpmValue) BPM at \(self.formatDate(sample.endDate))")
            
            DispatchQueue.main.async {
                // Only update if this is more recent than our current data
                if self.shouldUpdateHeartRate(newValue: bpmValue, source: "Historical") {
                    self.updateHeartRate(bpmValue, source: "Historical", timestamp: sample.endDate)
                }
            }
        }
        
        // Execute the query
        healthStore.execute(query)
    }
    
    // Set up a timer to periodically fetch the latest heart rate
    func startPeriodicHeartRateUpdates() {
        // Stop any existing timer
        updateTimer?.invalidate()
        
        // Create a timer that fires every 1 second
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isBeingWorn else { return }
            self.fetchLatestHeartRateSample()
        }
        
        print("Started periodic heart rate updates (every 1 second)")
    }
    
    // MARK: - Real-time Workout Session Methods
    
    // Start a workout session specifically for real-time heart rate monitoring
    func startRealTimeMonitoring() {
        debugState = "Starting Real-Time Monitoring"
        
        // If the watch is not being worn, don't start monitoring
        if !isBeingWorn {
            print("Not starting real-time monitoring - watch is not being worn")
            return
        }
        
        // If a session is already running, clean it up first
        if workoutSession != nil {
            stopRealTimeMonitoring()
        }
        
        // Create a workout configuration
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .mixedCardio
        configuration.locationType = .indoor
        
        do {
            print("Creating real-time workout session...")
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            
            workoutSession?.delegate = self
            workoutBuilder?.delegate = self
            
            // Configure for real-time data collection
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            
            print("Starting real-time workout session...")
            workoutSession?.startActivity(with: Date())
            workoutBuilder?.beginCollection(withStart: Date()) { [weak self] success, error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    if success {
                        print("Real-time workout session started successfully")
                        self.debugState = "Real-Time Monitoring Active"
                    } else {
                        if let error = error {
                            print("Failed to start real-time monitoring: \(error.localizedDescription)")
                            self.errorMessage = "Real-time error: \(error.localizedDescription)"
                        }
                    }
                }
            }
        } catch {
            print("Error creating real-time workout session: \(error.localizedDescription)")
        }
    }
    
    // Stop the real-time workout session
    func stopRealTimeMonitoring() {
        if let session = workoutSession {
            if session.state != .ended && session.state != .stopped {
                session.end()
            }
        }
        
        if let builder = workoutBuilder {
            builder.endCollection(withEnd: Date()) { _, _ in
                print("Real-time workout collection ended")
            }
        }
        
        workoutSession = nil
        workoutBuilder = nil
        
        print("Stopped real-time monitoring")
    }
    
    // MARK: - HKWorkoutSessionDelegate
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        print("Workout session state changed from \(fromState.rawValue) to \(toState.rawValue)")
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed: \(error.localizedDescription)")
    }
    
    // MARK: - HKLiveWorkoutBuilderDelegate
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        print("Workout Builder Collected an Event")
    }
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        
        if collectedTypes.contains(heartRateType) {
            if let statistics = workoutBuilder.statistics(for: heartRateType) {
                let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                
                if let mostRecentQuantity = statistics.mostRecentQuantity() {
                    let bpmValue = mostRecentQuantity.doubleValue(for: heartRateUnit)
                    let timestamp = Date() // Use current time for real-time data
                    
                    // Validate the heart rate reading
                    if isValidHeartRate(bpmValue) {
                        print("Real-time BPM value: \(bpmValue) at \(formatDate(timestamp))")
                        
                        // Getting a valid heart rate increases worn confidence
                        adjustWornConfidence(by: 5)
                        
                        DispatchQueue.main.async {
                            // Only update if this is more recent than our current data
                            if self.shouldUpdateHeartRate(newValue: bpmValue, source: "Real-time") {
                                self.updateHeartRate(bpmValue, source: "Real-time", timestamp: timestamp)
                            }
                        }
                    } else {
                        print("Invalid heart rate reading: \(bpmValue) - likely not worn properly")
                        
                        // Invalid heart rate decreases worn confidence
                        adjustWornConfidence(by: -5)
                    }
                }
            }
        }
    }
    
    // Validate heart rate reading
    private func isValidHeartRate(_ bpm: Double) -> Bool {
        // Check if the watch is being worn
        if !isBeingWorn {
            return false
        }
        
        // Check for physiologically impossible values
        if bpm < 30 || bpm > 220 {
            return false
        }
        
        // Check for suspiciously stable values (could indicate sensor issues)
        if bpm == currentBPM && bpm != 0 {
            // If the value hasn't changed at all, it might be suspicious
            // But we'll allow it if it's the first reading
            return currentBPM == 0
        }
        
        return true
    }
    
    func workoutBuilderDidFinish(_ workoutBuilder: HKLiveWorkoutBuilder, error: Error?) {
        if let error = error {
            print("Workout builder finished with error: \(error.localizedDescription)")
        } else {
            print("Workout builder finished successfully")
        }
    }
}
