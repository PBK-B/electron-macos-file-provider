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
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "groups.cloud.lazycat.clients") else {
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

    // 修剪日志文件，控制日志大小
    private func trimLogFileIfNeeded() {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: logFilePath, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            return
        }

        do {
            let fileAttributes = try fileManager.attributesOfItem(atPath: logFilePath)
            let fileSize = fileAttributes[.size] as! UInt64

            // 如果日志文件大小超过允许的总大小，则裁剪
            if fileSize > UInt64(3600 * 36) * 160 {
                let logContent = try String(contentsOfFile: logFilePath, encoding: .utf8)
                let logLines = logContent.components(separatedBy: .newlines)
                let newLogContent = logLines.suffix(3600 * 36).joined(separator: "\n")
                try newLogContent.write(toFile: logFilePath, atomically: true, encoding: .utf8)
            }
        } catch {
            debugPrint("修剪日志文件失败: \(error)")
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

                // 修剪日志文件，保持合适的文件大小
                FileProviderLogger.shared.trimLogFileIfNeeded()
            }
        }
    }

    // 公开的记录应用启动日志方法，用于日志间隔
    public static func logAppStartup() {
        FileProviderLogger.shared.logAppStartup()
    }
}
