//
//  MyCustomXPCProtocol.swift
//  EleFileProvider
//
//  Created by mac on 2024/9/13.
//

import Foundation

// 共享协议 (主进程和扩展都能使用)
@objc public protocol MyCustomXPCProtocol {
    func processRequest(url: URL, cookie: String, withReply reply: @escaping ([String: String]) -> Void)
}
