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
        
        public weak var delegate: FTPServiceDelegate?
        
        public var port: UInt16 { listener.port!.rawValue }
        
        public let path: String
        
        public private(set) var connects: [NWEndpoint: Connect] = [:]
        
        private var state: NWListener.State = .setup
        
        private let listener: NWListener
        private let queue = DispatchQueue(namespace: "Service")
        
        deinit {
            cancel()
        }
        
        public init(path: String = NSHomeDirectory(), port: UInt16 = 21) throws {
            self.path = path
            
            listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
            listener.stateUpdateHandler = { [weak self] in
                guard let self = self else { return }
                self.state = $0
                self.delegate?.service(self, change: $0)
            }
            listener.newConnectionHandler = { [weak self] in
                guard let self = self else { return }
                self.newConnectHandler($0)
            }
        }
        
    }
    
}

// MARK: - Public
public extension FTP.Service {
    
    func start() {
        listener.start(queue: queue)
    }
    
    func cancel() {
        if state == .cancelled { return }
        listener.cancel()
    }
    
}

// MARK: - Method
extension FTP.Service {
    
    func removeConnect(_ connect: Connect){
        connects[connect.endpoint] = nil
    }
    
}

// MARK: - Handler
private extension FTP.Service {
    
    func newConnectHandler(_ connect: NWConnection) {
        let connect = Connect(service: self, connect: connect)
        connect.start()
        connects[connect.endpoint] = connect
    }
    
}

// MARK: - FTPServiceDelegate
public protocol FTPServiceDelegate: AnyObject {
    
    func service(_ service: FTP.Service, change state: NWListener.State)
    
    func connect(_ connect: FTP.Service.Connect, login password: String) -> Bool
    
}
