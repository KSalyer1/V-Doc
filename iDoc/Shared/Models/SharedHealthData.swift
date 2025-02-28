//
//  SharedHealthData.swift
//  iDoc
//
//  Created by Keith  Salyer on 2/24/25.
//

import Foundation
import HealthKit

/// A shared model representing basic health metrics gathered from HealthKit.
struct SharedHealthData {
    var heartRate: Double        // Beats per minute
    var activeEnergyBurned: Double  // In kilocalories
    var distance: Double         // In meters
    var timestamp: Date
}
