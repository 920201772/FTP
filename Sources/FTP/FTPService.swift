//
//  FTPService.swift
//  
//
//  Created by 杨柳 on 2021/1/27.
//  Copyright © 2021 Kun. All rights reserved.
//

import Foundation
import Network

public extension FTP {
    
    final class Service {
        
        public var state: NWListener.State { listener.state }
        
        private let listener: NWListener
        private let queue = DispatchQueue(namespace: "Service")
        private var connects: [NWEndpoint: Connect] = [:]
        
        deinit {
            listener.cancel()
        }
        
        public init() throws {
            listener = try NWListener(using: .tcp, on: 21)
            listener.stateUpdateHandler = { [weak self] in
                guard let self = self else { return }
                self.stateChangeHandler($0)
            }
            listener.newConnectionHandler = { [weak self] in
                guard let self = self else { return }
                self.newConnectHandler($0)
            }
        }
        
    }
    
}

// MARK: - Method
public extension FTP.Service {
    
    func start() {
        listener.start(queue: queue)
        Log(listener)
    }
    
}

// MARK: - private
private extension FTP.Service {
    
}

// MARK: - Handler
private extension FTP.Service {
    
    func stateChangeHandler(_ state: NWListener.State) {
        Log(state)
    }
    
    func newConnectHandler(_ connect: NWConnection) {
        let connect = Connect(connect: connect)
        connect.delegate = self
        connect.start()
        connects[connect.endpoint] = connect
    }
    
}

// MARK: - FTPServiceConnectDelegate
extension FTP.Service: FTPServiceConnectDelegate {
    
    func connect(_ connect: Connect, change state: NWConnection.State) {
        Log(state)
        switch state {
        case .failed(_):
            connects[connect.endpoint] = nil
            
        case .cancelled:
            connects[connect.endpoint] = nil
            
        default: break
        }
    }
    
    func connect(_ connect: Connect, sendFail error: NWError) {
        Log(error)
    }
    
}
