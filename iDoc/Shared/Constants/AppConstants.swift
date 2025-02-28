//
//  AppConstants.swift
//  iDoc
//
//  Created by Keith  Salyer on 2/24/25.
//

import Foundation

struct AppConstants {
    struct HealthKitIdentifiers {
        static let heartRate = "HKQuantityTypeIdentifierHeartRate"
    }
    
    struct WatchConnectivityKeys {
        static let heartRate = "heartRate"
    }
    
    struct URLs {
        static let privacyPolicy = "https://yourdomain.com/privacy"
        static let termsOfService = "https://yourdomain.com/terms"
    }
    
    static let defaultWorkoutDuration: TimeInterval = 1800  // 30 minutes
}
