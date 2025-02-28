//
//  UnitConversion.swift
//  iDoc
//
//  Created by Keith  Salyer on 2/24/25.
//

import Foundation

struct UnitConversion {
    static func metersToMiles(_ meters: Double) -> Double {
        return meters * 0.000621371
    }
    
    static func metersToKilometers(_ meters: Double) -> Double {
        return meters / 1000.0
    }
    
    // Add additional conversions as needed.
}
