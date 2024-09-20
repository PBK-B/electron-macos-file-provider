import FileProvider
import Foundation
import os.log

@objcMembers
public final class FileProviderLogger: NSObject {
    // MARK: - 日志服务单例
    public static let shared = FileProviderLogger()
    private var logFilePath: String = ""
    private let logQueue = DispatchQueue(label: "com.appinformation.logQueue", attributes: .concurrent)
    
    // 记录是否已经记录启动日志
    private var hasLoggedStartup = false

    // 初始化方法
    private override init() {
        super.init()
        // 获取共享容器路径
        var appGroupID = "group.cloud.lazycat.clients"
        if let appGroups = Bundle.main.object(forInfoDictionaryKey: "com.apple.security.application-groups") as? [String] {
            if let ID = appGroups.first {
                print("App Groups ID: \(ID)")
                appGroupID = ID
            }
        }
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            print("Failed to get container URL")
            fatalError("获取共享容器路径失败")
        }

        
        // 确保日志目录存在
        let attributes: [FileAttributeKey: Any] = [
            .posixPermissions: 0o755, // 设置目录权限为755
            .ownerAccountID: getuid(), // 设置拥有者为当前用户
            .groupOwnerAccountID: getgid()
        ]
        // 设置日志目录
        let logDirectory = containerURL.appendingPathComponent("lzc-client-desktop", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true, attributes: attributes)
        } catch {
            print("Failed to create log directory: \(error)")
            fatalError("创建日志目录失败: \(error)")
        }

        // 设置日志文件路径
        let logFileURL = logDirectory.appendingPathComponent("fileProvider.log")
        logFilePath = logFileURL.path

        // 输出日志目录权限信息
        let permissions = try? FileManager.default.attributesOfItem(atPath: logDirectory.path)
        print("日志目录权限: \(String(describing: permissions))")
        
        // 测试写入文件权限
        let testFileURL = logDirectory.appendingPathComponent("testfile.txt")
        do {
            try "Test content".write(to: testFileURL, atomically: true, encoding: .utf8)
            print("成功写入测试文件.")
        } catch {
            print("写入测试文件失败: \(error)")
        }

        // 准备日志文件
        prepareLogFile()
    }

    // 准备日志文件，如果不存在则创建
    private func prepareLogFile() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: logFilePath) {
            fileManager.createFile(atPath: logFilePath, contents: nil, attributes: nil)
        }
    }

    // 修剪日志文件，控制日志大小 并改为流式的
    private func trimLogFileIfNeeded() throws {
        let maxSize: UInt64 = 15 * 1024 * 1024 // 限制文件大小为15MB
        let fileSize = try FileManager.default.attributesOfItem(atPath: self.logFilePath)[.size] as? UInt64 ?? 0
        
        // 如果文件大小超过了允许的最大值
        if fileSize > maxSize {
            // 创建一个临时文件用于保存新的日志内容
            let tempFilePath = self.logFilePath + ".tmp"
            FileManager.default.createFile(atPath: tempFilePath, contents: nil, attributes: nil)
            
            guard let inputStream = InputStream(fileAtPath: self.logFilePath),
                  let outputStream = OutputStream(toFileAtPath: tempFilePath, append: false) else { return }
            
            inputStream.open()
            outputStream.open()
            defer {
                inputStream.close()
                outputStream.close()
            }
            
            let delimiter = "\n".data(using: .utf8)!
            var lineData = Data()
            var currentFileSize: UInt64 = 0
            let bufferSize = 1024
            var buffer = Data(count: bufferSize)
            
            // 找到需要保留的最新日志行总大小
            while inputStream.hasBytesAvailable {
                buffer = Data(count: bufferSize)
                let bytesRead = buffer.withUnsafeMutableBytes {
                    inputStream.read($0.bindMemory(to: UInt8.self).baseAddress!, maxLength: bufferSize)
                }
                
                if bytesRead > 0 {
                    lineData.append(buffer.prefix(bytesRead))
                    
                    // 查找换行符，逐行处理
                    while let range = lineData.range(of: delimiter) {
                        let line = String(data: lineData.prefix(upTo: range.lowerBound), encoding: .utf8) ?? ""
                        currentFileSize += UInt64(line.utf8.count + 1) // +1 是换行符的大小
                        lineData.removeSubrange(..<range.upperBound)
                        
                        // 如果当前文件大小超过限制，直接跳过这些行，直到符合文件大小限制
                        if currentFileSize > maxSize {
                            continue
                        }
                        
                        // 写入输出流，保持最后的日志行
                        let data = line.data(using: .utf8)!
                        _ = data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
                            outputStream.write(ptr.bindMemory(to: UInt8.self).baseAddress!, maxLength: data.count)
                        }
                        _ = delimiter.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
                            outputStream.write(ptr.bindMemory(to: UInt8.self).baseAddress!, maxLength: delimiter.count)
                        }
                    }
                }
            }
            
            // 用处理后的文件替换原日志文件
            try FileManager.default.removeItem(atPath: self.logFilePath)
            try FileManager.default.moveItem(atPath: tempFilePath, toPath: self.logFilePath)
        }
    }

    // 记录应用启动日志
    private func logAppStartup() {
        let currentTime = getFormattedCurrentTime()
        let startupMessage = "\n===== App Started at \(currentTime) =====\n"
        FileProviderLogger.logAppInformation(startupMessage)
    }

    // 获取当前时间的格式化字符串
    private func getFormattedCurrentTime() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter.string(from: Date())
    }

    // 记录日志信息
    public static func logAppInformation(_ message: String) {
        if !FileProviderLogger.shared.hasLoggedStartup {
            FileProviderLogger.shared.hasLoggedStartup = true
            FileProviderLogger.shared.logAppStartup()
        }

        print("\(message)")

        // 使用异步队列写入日志
        FileProviderLogger.shared.logQueue.async(flags: .barrier) {
            let logString = message + "\n"
            if let data = logString.data(using: .utf8) {
                let fileURL = URL(fileURLWithPath: FileProviderLogger.shared.logFilePath)
                let fileHandle = try? FileHandle(forWritingTo: fileURL)

                if let fileHandle = fileHandle {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                } else {
                    do {
                        try data.write(to: fileURL, options: .atomic)
                        debugPrint("成功写入日志: \(message)")
                    } catch {
                        debugPrint("写入日志失败: \(error)")
                    }
                }

                // 维护日志文件大小
                Task{
                    do {
                        try FileProviderLogger.shared.trimLogFileIfNeeded()
                    }
                }
            }
        }
    }

    // 公开的记录应用启动日志方法，用于日志间隔
    public static func logAppStartup() {
        FileProviderLogger.shared.logAppStartup()
    }
}
