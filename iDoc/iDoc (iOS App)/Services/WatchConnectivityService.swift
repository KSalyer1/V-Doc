//
//  WatchConnectivityService.swift
//  iDoc
//
//  Created by Keith  Salyer on 2/24/25.
//

import WatchConnectivity

class WatchConnectivityService {
    static let shared = WatchConnectivityService()
    
    private init() { }
    
    func sendMessageToWatch(_ message: [String: Any]) {
        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                print("Error sending message to watch: \(error.localizedDescription)")
            }
        } else {
            print("Watch is not reachable")
        }
    }
}
