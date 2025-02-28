//
//  WorkoutSessionManager.swift
//  iDoc
//
//  Created by Keith  Salyer on 2/24/25.
//

import HealthKit

class WorkoutSessionManager: NSObject, ObservableObject {
    private var healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    
    @Published var heartRate: Double = 0.0

    func startWorkout() {
        let config = HKWorkoutConfiguration()
        config.activityType = .running
        config.locationType = .indoor

        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            builder = session?.associatedWorkoutBuilder()
            
            session?.delegate = self
            builder?.delegate = self

            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
            session?.startActivity(with: Date())
            builder?.beginCollection(withStart: Date(), completion: { (success, error) in
                if !success {
                    print("Error starting workout: \(error?.localizedDescription ?? "Unknown error")")
                }
            })
        } catch {
            print("Failed to start workout session: \(error.localizedDescription)")
        }
    }
}

// MARK: - HKWorkoutSessionDelegate
extension WorkoutSessionManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        print("Workout session state changed to \(toState)")
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed: \(error.localizedDescription)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension WorkoutSessionManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        print("Workout builder collected event")
    }

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            if let quantityType = type as? HKQuantityType, quantityType.identifier == HKQuantityTypeIdentifier.heartRate.rawValue {
                if let statistics = workoutBuilder.statistics(for: quantityType) {
                    let heartRateUnit = HKUnit(from: "count/min")
                    let value = statistics.mostRecentQuantity()?.doubleValue(for: heartRateUnit) ?? 0.0
                    DispatchQueue.main.async {
                        self.heartRate = value
                    }
                }
            }
        }
    }
}
