//
//  VitalStatView.swift
//  iDoc
//
//  Created by Keith  Salyer on 2/24/25.
//

import UIKit
import Foundation

class VitalStatView: UIView {
    
    private let heartRateLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        label.text = "HR: -- BPM"
        label.textAlignment = .center
        return label
    }()
    
    private let timestampLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.text = "Last update: --"
        label.textAlignment = .center
        return label
    }()
    
    private let sourceLabel: UILabel = {
        let label = UILabel()
        label.textColor = .lightGray
        label.font = UIFont.systemFont(ofSize: 10, weight: .regular)
        label.text = "Source: --"
        label.textAlignment = .center
        return label
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.textColor = .gray
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.text = "Waiting for data..."
        label.textAlignment = .center
        return label
    }()
    
    private var lastUpdateTime: Date?
    private var updateTimer: Timer?
    private var dataSource: String = "None"
    private var isWatchWorn: Bool = true
    private var wornState: String = "Worn"
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        // Create a stack view to hold the labels
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add labels to stack view
        stackView.addArrangedSubview(heartRateLabel)
        stackView.addArrangedSubview(timestampLabel)
        stackView.addArrangedSubview(sourceLabel)
        stackView.addArrangedSubview(statusLabel)
        
        // Add stack view to main view
        addSubview(stackView)
        
        // Constrain stack view
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8)
        ])
        
        // Start a timer to update the "time since last update" text
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimeSinceLastUpdate()
        }
    }
    
    deinit {
        updateTimer?.invalidate()
    }
    
    private func updateTimeSinceLastUpdate() {
        guard let lastUpdate = lastUpdateTime else { return }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let timeString = formatter.localizedString(for: lastUpdate, relativeTo: Date())
        
        DispatchQueue.main.async {
            self.timestampLabel.text = "Last update: \(timeString)"
            
            // Update status based on how old the data is
            let timeSinceUpdate = Date().timeIntervalSince(lastUpdate)
            if timeSinceUpdate > 60 {
                self.statusLabel.text = "Data may be stale"
                self.statusLabel.textColor = .orange
            } else {
                self.statusLabel.text = "Data is current"
                self.statusLabel.textColor = .green
            }
        }
    }
    
    func updateHeartRate(_ heartRate: Double, at date: Date, source: String = "Unknown", isWorn: Bool = true, wornState: String = "Worn") {
        DispatchQueue.main.async {
            self.isWatchWorn = isWorn
            self.wornState = wornState
            
            // Update timestamp if we have a valid date
            if let timestamp = self.lastUpdateTime {
                let formatter = DateFormatter()
                formatter.timeStyle = .medium
                let timeString = formatter.string(from: timestamp)
                self.timestampLabel.text = "Last update: \(timeString)"
            }
            
            // Only update heart rate if watch is being worn
            if isWorn {
                self.heartRateLabel.text = String(format: "HR: %.0f BPM", heartRate)
                self.lastUpdateTime = date
                self.dataSource = source
                
                // Update timestamp
                let formatter = DateFormatter()
                formatter.timeStyle = .medium
                let timeString = formatter.string(from: date)
                self.timestampLabel.text = "Last update: \(timeString)"
                
                // Update source
                self.sourceLabel.text = "Source: \(source)"
                
                // Set source label color based on the data source
                switch source {
                case "Real-time":
                    self.sourceLabel.textColor = UIColor.systemBlue
                case "Historical":
                    self.sourceLabel.textColor = UIColor.systemGreen
                default:
                    self.sourceLabel.textColor = UIColor.lightGray
                }
                
                // Update status
                self.statusLabel.text = "Data is current"
                self.statusLabel.textColor = .green
                
                // Log the update
                print("iOS UI updated with heart rate: \(heartRate) BPM from \(source) at \(timeString)")
            } else {
                // Show not worn status with -- BPM
                self.heartRateLabel.text = "HR: -- BPM"
                self.statusLabel.text = "Watch Not Worn"
                self.statusLabel.textColor = .red
                
                // Add a warning message
                self.sourceLabel.text = "⚠️ Please wear watch to monitor heart rate"
                self.sourceLabel.textColor = UIColor.systemOrange
            }
        }
    }
    
    // Update just the worn state without changing heart rate
    func updateWornState(isWorn: Bool, wornState: String) {
        DispatchQueue.main.async {
            self.isWatchWorn = isWorn
            self.wornState = wornState
            
            if !isWorn {
                // Show not worn status with -- BPM
                self.heartRateLabel.text = "HR: -- BPM"
                self.statusLabel.text = "Watch Not Worn"
                self.statusLabel.textColor = .red
                self.sourceLabel.text = "⚠️ Please wear watch to monitor heart rate"
                self.sourceLabel.textColor = UIColor.systemOrange
            } else {
                // Show worn status
                if self.lastUpdateTime != nil {
                    self.statusLabel.text = "Data is current"
                    self.statusLabel.textColor = .green
                    self.sourceLabel.text = "Source: \(self.dataSource)"
                }
            }
        }
    }
}
