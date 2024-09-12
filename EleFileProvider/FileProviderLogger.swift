//
//  FileProviderLogger.swift
//  EleFileProvider
//
//  Created by Bin on 2024/9/12.
//

import FileProvider
import Foundation
import os.log

public final class FileProviderLogger {
    // MARK: - 日志服务本身

    public static let shared = FileProviderLogger()
    private let logFilePath: String
    private let logQueue = DispatchQueue(label: "com.appinformation.logQueue", attributes: .concurrent)

    private init() {
        // 获取共享容器路径
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "A6954X9WMS.group.com.webdav.fjs") else {
            fatalError("Failed to get container URL")
        }

        // 设置日志目录
        let logDirectory = containerURL.appendingPathComponent("lzc-client-desktop", isDirectory: true)

        // 确保日志目录存在
        do {
            try FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            fatalError("Failed to create log directory: \(error)")
        }

        // 设置日志文件路径
        let logFileURL = logDirectory.appendingPathComponent("fileProvider.log")
        logFilePath = logFileURL.path

        // 现在所有存储属性都已经初始化完成
        print("Log file path: \(logFilePath)")

        // 准备日志文件
        prepareLogFile()
    }

    private func logAppStartup() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let currentTime = dateFormatter.string(from: Date())
        let startupMessage = "\n===== App Started at \(currentTime) =====\n"
        // 使用logAppInformation方法记录启动信息
        FileProviderLogger.logAppInformation(startupMessage)
    }

    private func prepareLogFile() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: logFilePath) {
            fileManager.createFile(atPath: logFilePath, contents: nil, attributes: nil)
        }
    }

    private func trimLogFileIfNeeded() {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: logFilePath, isDirectory: &isDirectory),
              !isDirectory.boolValue
        else {
            return
        }

        do {
            let fileAttributes = try fileManager.attributesOfItem(atPath: logFilePath)
            let fileSize = fileAttributes[.size] as! UInt64

            // 如果文件大小超过了bufferSize允许的总大小，进行裁剪
            if fileSize > UInt64(3600 * 36) * 160 { // 每条日志大约160字节
                let logContent = try String(contentsOfFile: logFilePath, encoding: .utf8)
                let logLines = logContent.components(separatedBy: .newlines)
                let newLogContent = logLines.suffix(3600 * 36).joined(separator: "\n")
                try newLogContent.write(toFile: logFilePath, atomically: true, encoding: .utf8)
            }
        } catch {
            debugPrint("Failed to trim log file: \(error)")
        }
    }

    public static func logAppStartup() {
        let currentTime = FileProviderLogger.shared.getFormattedCurrentTime()
        let startupMessage = "\n===== App Started at \(currentTime) =====\n"
        FileProviderLogger.logAppInformation(startupMessage)
    }

    private func getFormattedCurrentTime() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter.string(from: Date())
    }

    public static func logAppInformation(_ message: String) {
        // 如果是首次调用日志方法，添加启动日志
        if !FileProviderLogger.shared.hasLoggedStartup {
            FileProviderLogger.shared.hasLoggedStartup = true
            FileProviderLogger.logAppStartup()
        }

        // 终端输出
        //  logger.debug("\(message)")
        print("\(message)")
        // 写入日志
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
                        debugPrint("成功写入日志：\(message)")
                    } catch {
                        debugPrint("写入日志失败：\(error)")
                    }
                }

                // 维护日志文件大小
                FileProviderLogger.shared.trimLogFileIfNeeded()
            }
        }
    }

    // 记录启动日志状态
    private var hasLoggedStartup = false
}
