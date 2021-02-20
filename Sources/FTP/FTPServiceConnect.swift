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
    
    public final class Connect {
        
        public var state: NWConnection.State { connect.state }
        public var endpoint: NWEndpoint { connect.endpoint }
        public private(set) var username: String?
        
        private let connect: NWConnection
        private let queue = DispatchQueue(namespace: "Service.Connect")
        private unowned let service: FTP.Service
        
        private var currentPath: String
        private var dataConnect: FTP.Service.DataConnect?
        
        deinit {
            cancel()
        }
        
        init(service: FTP.Service, connect: NWConnection) {
            self.service = service
            self.connect = connect
            currentPath = service.path
            
            connect.stateUpdateHandler = { [weak self] in
                guard let self = self else { return }
                self.stateChangeHandler($0)
            }
        }
        
    }
    
}

// MARK: - Public
public extension FTP.Service.Connect {
    
    func cancel() {
        if connect.state == .cancelled { return }
        connect.cancel()
    }
    
}

// MARK: - Method
extension FTP.Service.Connect {
    
    func start() {
        connect.start(queue: queue)
    }
    
    func send(_ response: FTP.Response) {
        // FIXME: Test
        Log("send: \(response.text)")
        
        connect.send(content: response.text.data(using: .utf8), completion: .contentProcessed({ _ in }))
    }
    
}

// MARK: - Private
private extension FTP.Service.Connect {
    
    func receive() {
        connect.receive(minimumIncompleteLength: 1, maximumLength: FTP.maxReceiveLength) { [weak self] data, ctx, isFinal, error in
            guard let self = self else { return }
            
            // FIXME: Test
            Log("receive: \(String(data: data ?? Data(), encoding: .utf8) ?? "")")
            
            if let data = data {
                if let command = FTP.Command(String(data: data, encoding: .utf8)) {
                    self.receiveCommand(command)
                } else {
                    self.send(.invalidCommand)
                }
            }
            
            if isFinal {
                self.cancel()
            } else {
                self.receive()
            }
        }
    }
    
    func receiveCommand(_ command: FTP.Command) {
        switch command {
        case .ABOR:
            break
            
        case .ACCT(_):
            break
            
        case .ALLO(_):
            break
            
        case .APPE(_):
            break
            
        case .CDUP(_):
            break
            
        case .CWD(let dirpath):
            if dirpath.hasPrefix("/") {
                currentPath = dirpath
            } else {
                currentPath += "/\(dirpath)"
            }
            send(.fileAction)
            
        case .DELE(let filename):
            receiveRemoveCommand(filename)
        
        case .FEAT:
            send(.serviceState)
            
        case .HELP(_):
            break
            
        case .LIST(let name):
            dataConnect?.sendList(name.isEmpty ? currentPath : name)
            
        case .MODE(_):
            break
            
        case .MKD(let directory):
            let path = "\(currentPath)/\(directory)"
            do {
                try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: false)
                send(.pathSetup(path))
            } catch {
                send(.fileUnavailable)
            }
            
        case .NLST(_):
            break
            
        case .NOOP:
            break
            
        case .PASS(let password):
            if service.delegate?.connect(self, login: password) == true {
                send(.loginSuccess)
            } else {
                send(.loginFail)
            }
            
        case .PASV:
            do {
                dataConnect = try FTP.Service.DataConnect(connect: self)
                dataConnect?.start()
            } catch {
                send(.connectClosed)
            }
            
        case .PORT(_):
            break
            
        case .PWD:
            send(.pathSetup(currentPath))
            
        case .QUIT:
            send(.quit)
            cancel()
            
        case .REIN:
            break
            
        case .REST(_):
            break
            
        case .RETR(let filename):
            dataConnect?.sendFile("\(currentPath)/\(filename)")
            
        case .RMD(let directory):
            receiveRemoveCommand(directory)
            
        case .RNFR(_):
            break
            
        case .RNTO(_):
            break
            
        case .SITE(_):
            break
        
        case .SIZE(let filename):
            receiveSizeCommand(filename)
            
        case .SMNT(_):
            break
            
        case .STAT(_):
            break
            
        case .STOR(let filename):
            dataConnect?.receiveFile("\(currentPath)/\(filename)")
            
        case .STOU(_):
            break
            
        case .STRU(_):
            break
            
        case .SYST:
            break
            
        case .TYPE(let type):
            switch type {
            case "A", "I": send(.success)
            default: send(.invalidParams)
            }
            
        case .USER(let username):
            self.username = username
            send(.password)
        }
    }
    
    func receiveRemoveCommand(_ name: String) {
        do {
            try FileManager.default.removeItem(atPath: "\(currentPath)/\(name)")
            send(.fileAction)
        } catch {
            send(.fileUnavailable)
        }
    }
    
    func receiveSizeCommand(_ filename: String) {
        let url = URL(fileURLWithPath: "\(currentPath)/\(filename)")
        if let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
            send(.fileState("\(fileSize)"))
        } else {
            send(.fileUnavailable)
        }
    }
    
}

// MARK: - Handler
private extension FTP.Service.Connect {
    
    func stateChangeHandler(_ state: NWConnection.State) {
        switch state {
        case .failed(_), .cancelled:
            service.removeConnect(self)
        
        case .ready:
            send(.serverReady)
            receive()
            
        default: break
        }
    }
    
}
