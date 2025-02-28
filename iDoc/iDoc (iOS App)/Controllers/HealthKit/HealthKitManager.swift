//
//  HealthKitManager.swift
//  iDoc
//
//  Created by Keith  Salyer on 2/24/25.
//

import HealthKit

protocol HealthKitManagerDelegate: AnyObject {
    func healthKitManager(_ manager: HealthKitManager, didReceiveHeartRate heartRate: Double, at date: Date)
}

class HealthKitManager {
    let healthStore = HKHealthStore()
    weak var delegate: HealthKitManagerDelegate?
    
    // Timer to periodically re-run the query
    private var liveQueryTimer: Timer?
    
    /// Requests authorization for heart rate data.
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            let error = NSError(domain: "HealthKit", code: 0,
                                userInfo: [NSLocalizedDescriptionKey: "Heart rate type unavailable"])
            completion(false, error)
            return
        }
        let typesToRead: Set<HKObjectType> = [heartRateType]
        healthStore.requestAuthorization(toShare: [], read: typesToRead) { success, error in
            print("Heart rate authorization completed: success=\(success), error=\(String(describing: error))")
            completion(success, error)
        }
    }
    
    /// Queries for the most recent heart rate samples using an anchored query.
    func queryHeartRateSamples() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            print("Heart rate type unavailable for querying.")
            return
        }
        
        let query = HKAnchoredObjectQuery(type: heartRateType,
                                          predicate: nil,
                                          anchor: nil,
                                          limit: HKObjectQueryNoLimit) { [weak self] (query, samples, deletedObjects, newAnchor, error) in
            if let error = error {
                print("Error fetching heart rate samples: \(error.localizedDescription)")
                return
            }
            guard let heartRateSamples = samples as? [HKQuantitySample], !heartRateSamples.isEmpty else {
                print("No heart rate samples available.")
                return
            }
            // Get the most recent sample
            if let latestSample = heartRateSamples.last {
                let heartRate = latestSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
                print("Latest heart rate sample: \(heartRate) BPM at \(latestSample.startDate)")
                self?.delegate?.healthKitManager(self!, didReceiveHeartRate: heartRate, at: latestSample.startDate)
            }
        }
        
        query.updateHandler = { [weak self] (query, samples, deletedObjects, newAnchor, error) in
            if let error = error {
                print("Error updating heart rate samples: \(error.localizedDescription)")
                return
            }
            guard let heartRateSamples = samples as? [HKQuantitySample], !heartRateSamples.isEmpty else { return }
            if let latestSample = heartRateSamples.last {
                let heartRate = latestSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
                print("Updated heart rate sample: \(heartRate) BPM at \(latestSample.startDate)")
                self?.delegate?.healthKitManager(self!, didReceiveHeartRate: heartRate, at: latestSample.startDate)
            }
        }
        
        print("Executing heart rate query...")
        healthStore.execute(query)
    }
    
    /// Starts monitoring heart rate continuously by requesting authorization and then starting a periodic query.
    func startMonitoring() {
        requestAuthorization { [weak self] success, error in
            guard let self = self else { return }
            if success {
                DispatchQueue.main.async {
                    // Start initial query and then schedule a timer to re-run it.
                    self.queryHeartRateSamples()
                    self.liveQueryTimer?.invalidate()
                    self.liveQueryTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                        self.queryHeartRateSamples()
                    }
                }
            } else if let error = error {
                print("HealthKit authorization failed: \(error.localizedDescription)")
            }
        }
    }
    
    /// Stops the periodic query.
    func stopMonitoring() {
        liveQueryTimer?.invalidate()
        liveQueryTimer = nil
    }
}
