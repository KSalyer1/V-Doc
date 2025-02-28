//
//  VitalsPanelView.swift
//  iDoc
//
//  Created by Keith  Salyer on 2/24/25.
//

import UIKit
import SwiftUI
import Combine

class VitalsPanelView: UIView {
    private let vitalStatView = VitalStatView()
    private var cancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        setupObservers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        setupObservers()
    }
    
    private func setupView() {
        backgroundColor = UIColor.clear
        addSubview(vitalStatView)
        vitalStatView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            vitalStatView.topAnchor.constraint(equalTo: topAnchor),
            vitalStatView.leadingAnchor.constraint(equalTo: leadingAnchor),
            vitalStatView.trailingAnchor.constraint(equalTo: trailingAnchor),
            vitalStatView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    private func setupObservers() {
        // Combine multiple publishers to get all the data we need
        cancellable = Publishers.CombineLatest4(
            WatchSessionManager.shared.$latestHeartRate,
            WatchSessionManager.shared.$lastUpdateTime,
            WatchSessionManager.shared.$dataSource,
            WatchSessionManager.shared.$isWatchWorn
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] (bpm, timestamp, source, isWorn) in
            if let timestamp = timestamp {
                self?.vitalStatView.updateHeartRate(
                    bpm, 
                    at: timestamp, 
                    source: source, 
                    isWorn: isWorn, 
                    wornState: WatchSessionManager.shared.wornState
                )
            } else {
                self?.vitalStatView.updateHeartRate(
                    bpm, 
                    at: Date(), 
                    source: source, 
                    isWorn: isWorn, 
                    wornState: WatchSessionManager.shared.wornState
                )
            }
        }
        
        // Also observe just the worn state changes
        // This is needed because we might get worn state updates without heart rate updates
        Publishers.CombineLatest(
            WatchSessionManager.shared.$isWatchWorn,
            WatchSessionManager.shared.$wornState
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] (isWorn, wornState) in
            self?.vitalStatView.updateWornState(isWorn: isWorn, wornState: wornState)
        }
        .store(in: &cancellables)
    }
}
