//
//  MyCustomFileProviderService.swift
//  EleFileProvider
//
//  Created by mac on 2024/9/13.
//
import FileProvider

class MyCustomFileProviderService: NSObject, NSFileProviderServiceSource, NSXPCListenerDelegate, MyCustomXPCProtocol {
    var serviceName: NSFileProviderServiceName

    // 初始化方法
    init(serviceName: NSFileProviderServiceName) {
        FileProviderLogger.logAppInformation("xpc:服务端初始化")
        self.serviceName = serviceName
        super.init()
    }

    // 实现 makeListenerEndpoint 方法
    func makeListenerEndpoint() throws -> NSXPCListenerEndpoint {
        let listener = NSXPCListener.anonymous()
        listener.delegate = self
        listener.resume()
        FileProviderLogger.logAppInformation("xpc: Listener endpoint created")
        return listener.endpoint
    }

    // 实现 NSXPCListenerDelegate 方法
    func listener(_: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        FileProviderLogger.logAppInformation("xpc: New connection request")
        newConnection.exportedInterface = NSXPCInterface(with: MyCustomXPCProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }

    // 实现 MyCustomXPCProtocol 协议的方法
    func processRequest(url: URL, cookie: String, withReply reply: @escaping ([String: String]) -> Void) {
        FileProviderLogger.logAppInformation("xpc: 服务接收到请求 - URL: \(url.absoluteString), Cookie: \(cookie)")
        let response = [
            "ProcessedURL": url.absoluteString,
            "ReceivedCookie": cookie,
        ]
        reply(response)
    }
}
