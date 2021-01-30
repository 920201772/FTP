//
//  FTP.swift
//
//
//  Created by 杨柳 on 2021/1/27.
//  Copyright © 2021 Kun. All rights reserved.
//

import Foundation

public struct FTP {
    
    
    
}

// MARK: - ResponseCode
extension FTP {
    
    struct ResponseCode {
        
        static let serverReady = Self(state: .processed, type: .connect, text: "FTP server ready")
        
        var content: String {
            var this = state.rawValue + type.rawValue + detailed
            if let text = text {
                this += " \(text)"
            }
            this += "\r\n"
            
            return this
        }
        
        let state: State
        let type: Style
        let detailed: String
        let text: String?
        
        init(state: State, type: Style, detailed: String = "0", text: String? = nil) {
            self.state = state
            self.type = type
            self.detailed = detailed
            self.text = text
        }
        
        enum State: String {
            
            /// 未处理
            case unprocessed = "1"
            /// 完成处理
            case processed = "2"
            /// 正在处理
            case didprocessed = "3"
            /// 暂时错误
            case temporaryError = "4"
            /// 永久错误
            case error = "5"
            
        }
        
        enum Style: String {
            
            /// 语法错误
            case grammarError = "0"
            /// 信息
            case info = "1"
            /// 连接
            case connect = "2"
            /// 认证
            case authenticate = "3"
            /// 未定义
            case undefined = "4"
            /// 文件
            case file = "5"
            
        }
        
    }
    
}
