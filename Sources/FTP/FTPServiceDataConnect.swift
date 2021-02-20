//
//  FTPServiceDataConnect.swift
//  
//
//  Created by 杨柳 on 2021/2/1.
//  Copyright © 2021 Kun. All rights reserved.
//

import Foundation
import Network

extension FTP.Service {
    
    final class DataConnect: NSObject {
        
        private let listener: NWListener
        private let queue = DispatchQueue(namespace: "Service.DataConnect")
        private unowned let connect: FTP.Service.Connect
        
        private var dataConnect: NWConnection?
        private var sendHandlers: [() -> Void] = []
        private var file: FileHandle?
        private var state: NWListener.State = .setup
        private var isSend = false
        
        deinit {
            cancel()
        }
        
        init(connect: FTP.Service.Connect) throws {
            self.connect = connect
            listener = try NWListener(using: .tcp, on: 0)
            
            super.init()
            
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
extension FTP.Service.DataConnect {
    
    func start() {
        listener.start(queue: queue)
    }
    
    func sendList(_ path: String) {
        send { [unowned self] in
            do {
                let attrKeys: Set<URLResourceKey> = [.fileSecurityKey, .linkCountKey, .fileSizeKey, .contentModificationDateKey, .nameKey]
                
                let dateFormat = DateFormatter()
                dateFormat.dateFormat = "MMM dd HH:mm"
                dateFormat.locale = Locale(identifier: "en")
                
                var total = 0
                let list = try FileManager.default.contentsOfDirectory(at: .init(fileURLWithPath: path), includingPropertiesForKeys: .init(attrKeys), options: [.skipsHiddenFiles]).reduce("") { result, url in
                    guard let attr = try? url.resourceValues(forKeys: attrKeys),
                          let fileSecurity = attr.fileSecurity,
                          let linkCount = attr.linkCount,
                          let size = attr.fileSize ?? 0,
                          let modifyDate = attr.contentModificationDate,
                          let name = attr.name else {
                        return result
                    }
                    
                    var mode: mode_t = 0
                    var authority = ""
                    CFFileSecurityGetMode(fileSecurity, &mode)
                    authority += mode & S_IFDIR == S_IFDIR ? "d" : "-"
                    authority += mode & S_IRUSR == S_IRUSR ? "r" : "-"
                    authority += mode & S_IWUSR == S_IWUSR ? "w" : "-"
                    authority += mode & S_IXUSR == S_IXUSR ? "x" : "-"
                    authority += mode & S_IRGRP == S_IRGRP ? "r" : "-"
                    authority += mode & S_IWGRP == S_IWGRP ? "w" : "-"
                    authority += mode & S_IXGRP == S_IXGRP ? "x" : "-"
                    authority += mode & S_IROTH == S_IROTH ? "r" : "-"
                    authority += mode & S_IWOTH == S_IWOTH ? "w" : "-"
                    authority += mode & S_IXOTH == S_IXOTH ? "x" : "-"
                    
                    var uid: uid_t = 0
                    CFFileSecurityGetOwner(fileSecurity, &uid)
                    let owner: String
                    if let pw_name = getpwuid(uid)?.pointee.pw_name {
                        owner = String(cString: pw_name)
                    } else {
                        owner = "\(uid)"
                    }

                    var gid: gid_t = 0
                    CFFileSecurityGetGroup(fileSecurity, &gid)
                    let group: String
                    if let gr_name = getgrgid(gid)?.pointee.gr_name {
                        group = String(cString: gr_name)
                    } else {
                        group = "\(gid)"
                    }
                    
                    total += 1
                    
                    return result + "\(authority) \(linkCount) \(owner) \(group) \(size) \(dateFormat.string(from: modifyDate)) \(name)\n"
                }
                
                self.send("total \(total)\n\(list)".data(using: .utf8) ?? Data()) { _ in
                    self.cancel()
                }
            } catch {
                self.connect.send(.invalidParams)
            }
        }
    }
    
    func sendFile(_ path: String) {
        send { [unowned self] in
            guard let stream = InputStream(fileAtPath: path) else {
                connect.send(.fileUnavailable)
                return
            }
            
            stream.delegate = self
            stream.schedule(in: .main, forMode: .common)
            stream.open()
        }
    }
    
    func receiveFile(_ path: String) {
        guard FileManager.default.createFile(atPath: path, contents: nil),
           let file = FileHandle(forWritingAtPath: path) else {
            connect.send(.fileUnallow)
            return
        }
        
        self.file = file
        
        guard let dataConnect = dataConnect else { return }
        
        switch dataConnect.state {
        case .setup, .failed(_), .cancelled:
            connect.send(.openDataConnect)
            dataConnect.start(queue: queue)
            
        case .waiting(_), .preparing:
            break
            
        case .ready:
            connect.send(.transportData)
            receive()
            
        @unknown default:
            break
        }
    }
    
}

// MARK: - Private
private extension FTP.Service.DataConnect {
    
    func cancel() {
        if state == .cancelled { return }
        dataConnect?.cancel()
        listener.cancel()
    }
    
    func send(_ handler: @escaping () -> Void) {
        guard let dataConnect = dataConnect else {
            sendHandlers.append(handler)
            return
        }
        
        switch dataConnect.state {
        case .setup, .waiting(_), .preparing: sendHandlers.append(handler)
        case .ready: handler()
        case .failed(_), .cancelled: connect.send(.connectClosed)
        @unknown default:
            break
        }
    }
    
    func send(_ data: Data, completionHandler: ((NWError?) -> Void)? = nil) {
        if !isSend {
            isSend = true
            connect.send(.transportData)
        }
        
        dataConnect?.send(content: data, completion: .contentProcessed({
            completionHandler?($0)
        }))
    }
    
    func startSend() {
        sendHandlers.forEach { $0() }
        sendHandlers = []
    }
    
    func receive() {
        guard let file = file else { return }
        
        dataConnect?.receive(minimumIncompleteLength: 1, maximumLength: FTP.maxReceiveLength) { [weak self] data, ctx, isFinal, error in
            guard let self = self else { return }
            if let data = data {
                file.write(data)
            }
            
            if isFinal {
                self.cancel()
            } else {
                self.receive()
            }
        }
    }
    
}

// MARK: - Handler
private extension FTP.Service.DataConnect {
    
    func stateChangeHandler(_ state: NWListener.State) {
        self.state = state
        switch state {
        case .setup, .waiting(_), .cancelled:
            break
        
        case .failed(_):
            connect.send(.connectClosed)
        
        case .ready:
            guard let ip = FTP.en0IPv4Address?.replacingOccurrences(of: ".", with: ","),
                  let port = listener.port?.rawValue else {
                connect.send(.connectClosed)
                return
            }
            
            connect.send(.passiveMode(ip, port: port))
            
        @unknown default:
            break
        }
    }
    
    func newConnectHandler(_ dataConnect: NWConnection) {
        if let dataConnect = self.dataConnect, dataConnect.state == .cancelled {
            dataConnect.cancel()
        }
        
        self.dataConnect = dataConnect
        dataConnect.stateUpdateHandler = { [weak self] in
            guard let self = self else { return }
            switch $0 {
            case .setup, .waiting(_), .preparing:
                break
                
            case .ready:
                self.startSend()
                self.receive()
                
            case .failed(_):
                self.connect.send(.unopenDataConnect)
                
            case .cancelled:
                if let file = self.file {
                    file.closeFile()
                    self.file = nil
                }
                
                self.connect.send(.closeDataConnect)
                self.dataConnect = nil
                
            @unknown default:
                break
            }
        }
        
        dataConnect.start(queue: queue)
    }
    
}

// MARK: - StreamDelegate
extension FTP.Service.DataConnect: StreamDelegate {
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        queue.async { [weak self] in
            guard let self = self else { return }
            switch eventCode {
            case .hasBytesAvailable:
                let stream = aStream as! InputStream
                let mpData = UnsafeMutablePointer<UInt8>.allocate(capacity: FTP.maxReceiveLength)
                let length = stream.read(mpData, maxLength: FTP.maxReceiveLength)
                if length != 0 {
                    self.send(Data(bytes: mpData, count: length))
                }
                mpData.deallocate()
                
            case .errorOccurred, .endEncountered:
                aStream.close()
                aStream.remove(from: .main, forMode: .common)
                self.cancel()
            
            default:
                break
            }
        }
    }
    
}
