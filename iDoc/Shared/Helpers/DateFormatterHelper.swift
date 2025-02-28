//
//  DateFormatterHelper.swift
//  iDoc
//
//  Created by Keith  Salyer on 2/24/25.
//

import Foundation

struct DateFormatterHelper {
    static func formattedDate(from date: Date, dateStyle: DateFormatter.Style = .medium, timeStyle: DateFormatter.Style = .short) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter.string(from: date)
    }
}
