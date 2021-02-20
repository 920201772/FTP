//
//  FTP.swift
//
//
//  Created by 杨柳 on 2021/1/27.
//  Copyright © 2021 Kun. All rights reserved.
//

import Foundation

public struct FTP {
    
    static let maxReceiveLength = Int(UInt16.max)
    
    static var en0IPv4Address: String? {
        var address : String?

        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }

        // For each interface ...
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee

            // Check for IPv4 interface:
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {

                // Check interface name:
                let name = String(cString: interface.ifa_name)
                if  name == "en0" {

                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)

        return address
    }
    
}

// MARK: - Nested
extension FTP {
    
    enum Response {
        
        /// 125 数据连接已打开, 传输开始
        case transportData
        /// 150 文件状态OK, 将打开数据连接
        case openDataConnect
        /// 200 成功
        case success
        /// 211 服务状态回复
        case serviceState
        /// 213 文件状态回复
        case fileState(_ state: String)
        /// 221 退出网络
        case quit
        /// 220 服务就绪
        case serverReady
        /// 226 结束数据连接
        case closeDataConnect
        /// 227 被动模式
        case passiveMode(_ ip: String, port: UInt16)
        /// 230 登录成功
        case loginSuccess
        /// 250 文件行为完成
        case fileAction
        /// 257 路径名建立
        case pathSetup(_ path: String)
        /// 331 需要密码
        case password
        /// 425 无法打开数据连接
        case unopenDataConnect
        /// 426 连接关闭
        case connectClosed
        /// 500 无效命令
        case invalidCommand
        /// 504 无效命令参数
        case invalidParams
        /// 530 未登录网络
        case loginFail
        /// 553 文件名不允许
        case fileUnallow
        /// 550 文件不可用
        case fileUnavailable
        /// 其它响应
        case other(_ code: String, _ content: String)
        
        var text: String {
            switch self {
            case .transportData: return "125 \r\n"
            case .openDataConnect: return "150 \r\n"
            case .success: return "200 \r\n"
            case .serviceState: return "211 \r\n"
            case .fileState(let state): return "213 \(state)\r\n"
            case .quit: return "221 \r\n"
            case .serverReady: return "220 \r\n"
            case .closeDataConnect: return "226 \r\n"
            case .passiveMode(let ip, let port): return "227 (\(ip),\(port >> 8),\(port & 0xFF))\r\n"
            case .loginSuccess: return "230 \r\n"
            case .fileAction: return "250 \r\n"
            case .pathSetup(let path): return "257 \"\(path)\"\r\n"
            case .password: return "331 \r\n"
            case .unopenDataConnect: return "425 \r\n"
            case .connectClosed: return "426 \r\n"
            case .invalidCommand: return "500 \r\n"
            case .invalidParams: return "504 \r\n"
            case .loginFail: return "530 \r\n"
            case .fileUnallow: return "533 \r\n"
            case .fileUnavailable: return "550 \r\n"
            case .other(let code, let content): return "\(code) \(content)\r\n"
            }
        }
        
    }
    
    enum Command {
        
        ///  中断数据连接程序
        case ABOR
        /// 系统特权帐号
        case ACCT(_ account: String)
        /// 为服务器上的文件存储器分配字节
        case ALLO(_ bytes: String)
        /// 添加文件到服务器同名文件
        case APPE(_ filename: String)
        /// 改变服务器上的父目录
        case CDUP(_ dirpath: String)
        /// 改变服务器上的工作目录
        case CWD(_ dirpath: String)
        /// 删除服务器上的指定文件
        case DELE(_ filename: String)
        /// 服务器实现的功能列表
        case FEAT
        /// 返回指定命令信息
        case HELP(_ command: String)
        /// 如果是文件名列出文件信息, 如果是目录则列出文件列表
        case LIST(_ name: String)
        /// 传输模式 (S=流模式, B=块模式, C=压缩模式)
        case MODE(_ mode: String)
        /// 在服务器上建立指定目录
        case MKD(_ directory: String)
        /// 列出指定目录内容
        case NLST(_ directory: String)
        /// 无动作, 除了来自服务器上的承认
        case NOOP
        /// 系统登录密码
        case PASS(_ password: String)
        /// 被动模式, 请求服务器等待数据连接
        case PASV
        /// 主动模式, IP地址和两字节的端口ID
        case PORT(_ address: String)
        /// 显示当前工作目录
        case PWD
        /// 从 FTP 服务器上退出登录
        case QUIT
        /// 重新初始化登录状态连接
        case REIN
        /// 由特定偏移量重启文件传递
        case REST(_ offset: String)
        /// 从服务器上找回（复制）文件
        case RETR(_ filename: String)
        /// 在服务器上删除指定目录
        case RMD(_ directory: String)
        /// 对旧路径重命名
        case RNFR(_ oldpath: String)
        /// 对新路径重命名
        case RNTO(_ newpath: String)
        /// 由服务器提供的站点特殊参数
        case SITE(_ params: String)
        /// 获取文件大小
        case SIZE(_ filename: String)
        /// 挂载指定文件结构
        case SMNT(_ pathname: String)
        /// 在当前程序或目录上返回信息
        case STAT(_ directory: String)
        /// 储存（复制）文件到服务器上
        case STOR(_ filename: String)
        /// 储存文件到服务器名称上
        case STOU(_ filename: String)
        /// 数据结构 (F=文件, R=记录, P=页面)
        case STRU(_ type: String)
        /// 返回服务器使用的操作系统
        case SYST
        /// 数据类型 (A=ASCII, E=EBCDIC, I=binary)
        case TYPE(_ datatype: String)
        /// 系统登录的用户名
        case USER(_ username: String)
        
        var text: String {
            switch self {
            case .ABOR: return "ABOR\r\n"
            case .ACCT(let account): return "ACCT \(account)\r\n"
            case .ALLO(let bytes): return "ALLO \(bytes)\r\n"
            case .APPE(let filename): return "APPE \(filename)\r\n"
            case .CDUP(let dirpath): return "CDUP \(dirpath)\r\n"
            case .CWD(let dirpath): return "CWD \(dirpath)\r\n"
            case .DELE(let filename): return "DELE \(filename)\r\n"
            case .FEAT: return "FEAT \r\n"
            case .HELP(let command): return "HELP \(command)\r\n"
            case .LIST(let name): return "LIST \(name)\r\n"
            case .MODE(let mode): return "MODE \(mode)\r\n"
            case .MKD(let directory): return "MKD \(directory)\r\n"
            case .NLST(let directory): return "NLST \(directory)\r\n"
            case .NOOP: return " NOOP\r\n"
            case .PASS(let password): return "PASS \(password)\r\n"
            case .PASV: return "PASV\r\n"
            case .PORT(let address): return "PORT \(address)\r\n"
            case .PWD: return "PWD\r\n"
            case .QUIT: return "QUIT\r\n"
            case .REIN: return "REIN\r\n"
            case .REST(let offset): return "REST \(offset)\r\n"
            case .RETR(let filename): return "RETR \(filename)\r\n"
            case .RMD(let directory): return "RMD \(directory)\r\n"
            case .RNFR(let oldpath): return "RNFR \(oldpath)\r\n"
            case .RNTO(let newpath): return "RNTO \(newpath)\r\n"
            case .SITE(let params): return "SITE \(params)\r\n"
            case .SIZE(let filename): return "SIZE \(filename)\r\n"
            case .SMNT(let pathname): return "SMNT \(pathname)\r\n"
            case .STAT(let directory): return "STAT \(directory)\r\n"
            case .STOR(let filename): return "STOR \(filename)\r\n"
            case .STOU(let filename): return "STOU \(filename)\r\n"
            case .STRU(let type): return "STRU \(type)\r\n"
            case .SYST: return "SYST\r\n"
            case .TYPE(let datatype): return "TYPE \(datatype)\r\n"
            case .USER(let username): return "USER \(username)\r\n"
            }
        }
        
        init?(_ text: String?) {
            guard let text = text else { return nil }
            let params = text.trimmingCharacters(in: .newlines).split(separator: " ", maxSplits: 1)
            
            switch params.first {
            case "ABOR":
                self = .ABOR
                
            case "ACCT":
                guard let account = params[safe: 1] else { return nil }
                self = .ACCT(String(account))
                
            case "ALLO":
                guard let bytes = params[safe: 1] else { return nil }
                self = .ALLO(String(bytes))
                
            case "APPE":
                guard let filename = params[safe: 1] else { return nil }
                self = .APPE(String(filename))
                
            case "CDUP":
                guard let dirpath = params[safe: 1] else { return nil }
                self = .CDUP(String(dirpath))
                
            case "CWD":
                guard let dirpath = params[safe: 1] else { return nil }
                self = .CWD(String(dirpath))
                
            case "DELE":
                guard let filename = params[safe: 1] else { return nil }
                self = .DELE(String(filename))
                
            case "FEAT":
                self = .FEAT
                
            case "HELP":
                guard let command = params[safe: 1] else { return nil }
                self = .HELP(String(command))
                
            case "LIST":
                let name = params[safe: 1] ?? ""
                self = .LIST(String(name))
                
            case "MODE":
                guard let mode = params[safe: 1] else { return nil }
                self = .MODE(String(mode))
                
            case "MKD":
                guard let directory = params[safe: 1] else { return nil }
                self = .MKD(String(directory))
                
            case "NLST":
                guard let directory = params[safe: 1] else { return nil }
                self = .NLST(String(directory))
                
            case "NOOP":
                self = .NOOP
                
            case "PASS":
                guard let password = params[safe: 1] else { return nil }
                self = .PASS(String(password))
                
            case "PASV":
                self = .PASV
                
            case "PORT":
                guard let address = params[safe: 1] else { return nil }
                self = .PORT(String(address))
                
            case "PWD":
                self = .PWD
                
            case "QUIT":
                self = .QUIT
                
            case "REIN":
                self = .REIN
                
            case "REST":
                guard let offset = params[safe: 1] else { return nil }
                self = .REST(String(offset))
                
            case "RETR":
                guard let filename = params[safe: 1] else { return nil }
                self = .RETR(String(filename))
                
            case "RMD":
                guard let directory = params[safe: 1] else { return nil }
                self = .RMD(String(directory))
                
            case "RNFR":
                guard let oldpath = params[safe: 1] else { return nil }
                self = .RNFR(String(oldpath))
                
            case "RNTO":
                guard let newpath = params[safe: 1] else { return nil }
                self = .RNTO(String(newpath))
                
            case "SITE":
                guard let params = params[safe: 1] else { return nil }
                self = .SITE(String(params))
                
            case "SIZE":
                guard let state = params[safe: 1] else { return nil }
                self = .SIZE(String(state))
                
            case "SMNT":
                guard let pathname = params[safe: 1] else { return nil }
                self = .SMNT(String(pathname))
                
            case "STAT":
                guard let directory = params[safe: 1] else { return nil }
                self = .STAT(String(directory))
                
            case "STOR":
                guard let filename = params[safe: 1] else { return nil }
                self = .STOR(String(filename))
                
            case "STOU":
                guard let filename = params[safe: 1] else { return nil }
                self = .STOU(String(filename))
                
            case "STRU":
                guard let type = params[safe: 1] else { return nil }
                self = .STRU(String(type))
                
            case "SYST":
                self = .SYST
                
            case "TYPE":
                guard let datatype = params[safe: 1] else { return nil }
                self = .TYPE(String(datatype))
                
            case "USER":
                guard let username = params[safe: 1] else { return nil }
                self = .USER(String(username))
                
            default:
                return nil
            }
        }
        
    }
    
}

// MARK: - Extension
private extension Collection {
    
    /// 安全索引
    subscript(safe index: Index?) -> Element? {
        guard let index = index else { return nil }
        return index.contains(startIndex..<endIndex) ? self[index] : nil
    }
    
    
    
}

private extension Comparable {
    
    /// 是否在范围内(闭区间,[0..<2])
    func contains(_ range: Range<Self>) -> Bool {
        return range.contains(self)
    }
    
}
