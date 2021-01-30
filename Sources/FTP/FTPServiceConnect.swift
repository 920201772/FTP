//
//  FTPServiceConnect.swift
//
//
//  Created by 杨柳 on 2021/1/29.
//  Copyright © 2021 Kun. All rights reserved.
//

import Foundation
import Network

extension FTP.Service {
    
    final class Connect {
        
        var state: NWConnection.State { connect.state }
        var endpoint: NWEndpoint { connect.endpoint }
        
        weak var delegate: FTPServiceConnectDelegate?
        
        private let connect: NWConnection
        private let queue = DispatchQueue(namespace: "Service.Connect")
        
        deinit {
            connect.cancel()
        }
        
        init(connect: NWConnection) {
            self.connect = connect
            
            connect.stateUpdateHandler = { [weak self] _ in
                guard let self = self else { return }
                self.stateChangeHandler()
            }
        }
        
    }
    
}

// MARK: - Method
extension FTP.Service.Connect {
    
    func start() {
        connect.start(queue: queue)
        Log(connect)
    }
    
}

// MARK: - Private
private extension FTP.Service.Connect {
    
    func send(_ text: String) {
        connect.send(content: text.data(using: .utf8), completion: .contentProcessed({ [weak self] in
            guard let self = self else { return }
            if let error = $0 {
                self.delegate?.connect(self, sendFail: error)
            }
        }))
    }
    
    func receive() {
        // 1460
        if #available(iOS 13, *) {
            Log(connect.maximumDatagramSize)
        }
        self.connect.receive(minimumIncompleteLength: 1, maximumLength: 1000) { [weak self] data, ctx, isSuccess, error in
            guard let self = self else { return }
            Log("\(self.connect)\n\(String(data: data ?? Data(), encoding: .utf8))\n\(isSuccess)\n\(error)")
            Log("\(ctx?.identifier)\n\(ctx?.isFinal)")
//            self.receive()
        }
//        NWConnection.ContentContext
        
//        connect.receiveMessage { [weak self] data, ctx, isSuccess, error in
//            guard let self = self else { return }
//            Log("\(self.connect)\n\(String(data: data ?? Data(), encoding: .utf8))\n\(ctx)\n\(isSuccess)\n\(error)")
////            self.receive()
//        }
    }
    
}

// MARK: - Handler
private extension FTP.Service.Connect {
    
    func stateChangeHandler() {
        switch state {
        case .ready:
            send(FTP.ResponseCode.serverReady.content)
            receive()
            
        default: break
        }
        
        self.delegate?.connect(self, change: state)
    }
    
}

protocol FTPServiceConnectDelegate: AnyObject {
    
    func connect(_ connect: FTP.Service.Connect, change state: NWConnection.State)
    func connect(_ connect: FTP.Service.Connect, sendFail error: NWError)
    
}
