//
//  WatchConnectivityService.swift
//  iDoc
//
//  Created by Keith  Salyer on 2/24/25.
//

import WatchConnectivity

class WatchConnectivityService: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = WatchConnectivityService()
    private var session: WCSession
    
    @Published var activationState: WCSessionActivationState = .notActivated
    @Published var isReachable: Bool = false
    
    override init() {
        session = WCSession.default
        super.init()
        
        print("Initializing WatchConnectivityService")
        if WCSession.isSupported() {
            print("WCSession is supported, setting delegate")
            session.delegate = self
            print("Activating WCSession...")
            session.activate()
        } else {
            print("WCSession is not supported on this device")
        }
    }
    
    func sendMessage(_ message: [String: Any]) {
        // Update reachability status
        self.isReachable = session.isReachable
        
        print("Attempting to send message: \(message)")
        print("Session activation state: \(activationState.rawValue)")
        print("Session reachable: \(session.isReachable)")
        
        // Only proceed if session is activated
        guard activationState == .activated else {
            print("Cannot send message - WCSession not activated (state: \(activationState.rawValue))")
            
            // Try to activate again if not activated
            if activationState == .notActivated {
                print("Attempting to activate WCSession again...")
                session.activate()
            }
            
            // Still try to update application context as it will be delivered when possible
            do {
                try session.updateApplicationContext(message)
                print("Updated application context (session not activated)")
            } catch {
                print("Failed to update application context: \(error.localizedDescription)")
            }
            return
        }
        
        if session.isReachable {
            session.sendMessage(message, replyHandler: { reply in
                print("Message sent successfully with reply: \(reply)")
            }, errorHandler: { error in
                print("Error sending message: \(error.localizedDescription)")
                
                // Fallback to application context if message sending fails
                do {
                    try self.session.updateApplicationContext(message)
                    print("Updated application context as fallback")
                } catch {
                    print("Failed to update application context: \(error.localizedDescription)")
                }
            })
        } else {
            print("iPhone not reachable, updating application context instead")
            // Use application context as a fallback - guaranteed delivery when phone becomes reachable
            do {
                try session.updateApplicationContext(message)
                print("Updated application context since phone not reachable")
            } catch {
                print("Failed to update application context: \(error.localizedDescription)")
            }
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.activationState = state
            self.isReachable = session.isReachable
        }
        
        if let error = error {
            print("WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("WCSession activated successfully with state: \(state.rawValue)")
            
            // These properties are only available on iOS
            #if os(iOS)
            // Print additional session information
            print("WCSession isPaired: \(session.isPaired)")
            print("WCSession isWatchAppInstalled: \(session.isWatchAppInstalled)")
            print("WCSession isComplicationEnabled: \(session.isComplicationEnabled)")
            #endif
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            print("Received message from iPhone: \(message)")
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) { }
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
