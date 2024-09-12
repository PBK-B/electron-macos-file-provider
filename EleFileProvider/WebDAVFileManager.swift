//
//  WebDAVFileManager.swift
//  EleFileProvider
//
//  Created by Bin on 2024/9/12.
//

import FileProvider
import Foundation
import WebDavKit

// WebDAV 文件管理器
class WebDAVFileManager {
    private let webDAV: WebDAV

    init(webDAV: WebDAV) {
        self.webDAV = webDAV
    }

    // MARK: - WebDAv方法

    // 检查WebDav是否连接成功
    func checkLinkStatus() async throws -> Bool {
        return await webDAV.ping()
    }

    // 列出 WebDAV 服务器上的文件
    func listFiles(atPath path: String) async throws -> [WebDAVFile] {
        return try await webDAV.listFiles(atPath: path)
    }

    // 下载 WebDAV 上的文件
    func downloadFile(atPath path: String) async throws -> URL {
        return try await webDAV.downloadFile(atPath: path)
    }

    // 上传文件到 WebDAV
    func uploadFile(atPath path: String, data: Data) async throws -> Bool {
        return try await webDAV.uploadFile(atPath: path, data: data)
    }

    // 删除 WebDAV 上的文件
    func deleteFile(atPath path: String) async throws -> Bool {
        return try await webDAV.deleteFile(atPath: path)
    }

    // 创建WebDAV 上的文件
    func createFolder(atPath path: String) async throws -> Bool {
        return try await webDAV.createFolder(atPath: path)
    }

    // 移动文件
    func moveFile(fromPath: String, toPath: String) async throws -> Bool {
        return try await webDAV.moveFile(fromPath: fromPath, toPath: toPath)
    }

    // 复制文件
    func copyFile(fromPath: String, toPath: String) async throws -> Bool {
        return try await webDAV.copyFile(fromPath: fromPath, toPath: toPath)
    }

    // 校验文件是否存在
    func fileExists(atPath: String) async throws -> Bool {
        return try await webDAV.fileExists(at: atPath)
    }

    /// 校验是否文件夹
    func isDirectory(atPath path: String) async throws -> Bool {
        return try await webDAV.isDirectory(atPath: path)
    }

    /// 从ID获取路径
    func pathForIdentifier(_ identifier: NSFileProviderItemIdentifier) async -> String {
        var path: String

        switch identifier {
        case .rootContainer:
            path = "/"
        case .workingSet:
            path = "/"
        case .trashContainer:
            path = "/"
        default:
            path = identifier.rawValue
        }

        // 移除路径开头的多余斜杠，确保路径格式正确
        while path.hasPrefix("//") {
            path.removeFirst()
        }

        // 判断是否单个文件，路径上则需要增加前缀/方便WebDAV访问。系统单个文件不会增加这个
        if !path.hasPrefix("/") && !path.hasPrefix(".Trash") {
            path = "/" + path
        }

        // 动态检测并添加文件扩展名（如果有）
        if let fileExtension = await detectFileExtension(for: path) {
            FileProviderLogger.logAppInformation("WAD测试: 文件增加拓展名，拓展名是：\(fileExtension)")
            path += fileExtension
        }

        FileProviderLogger.logAppInformation("WAD测试: 系统Item \(String(describing: type(of: self))) 系统ID：\(String(describing: identifier)) 转化后的path  \(path)")
        return path
    }

    /// 从路径转换ID
    func identifierForPath(_ path: String) -> NSFileProviderItemIdentifier {
        var identififer: NSFileProviderItemIdentifier
        var tempPath = path

        if tempPath == "/" {
            identififer = NSFileProviderItemIdentifier.rootContainer
        } else if tempPath == ".Trash/" {
            identififer = NSFileProviderItemIdentifier.trashContainer
        } else {
            // 增加/ 变为有效路径
            if !tempPath.hasPrefix("/") && !tempPath.hasPrefix(".Trash") {
                tempPath = "/" + tempPath
            }
            let normalizedPath = tempPath.hasSuffix("/") && tempPath.count > 1 ? String(tempPath.dropLast()) : tempPath
            identififer = NSFileProviderItemIdentifier(rawValue: normalizedPath)
        }

        FileProviderLogger.logAppInformation("WAD测试: \(String(describing: type(of: self))) 传入的Path：\(tempPath) 转化后的ID \(String(describing: identififer))")
        return identififer
    }

    // 动态检测并返回文件的扩展名（如果有）
    func detectFileExtension(for path: String) async -> String? {
        // 获取父目录路径和文件名
        let directoryPath = (path as NSString).deletingLastPathComponent
        let fileNameWithoutExtension = (path as NSString).lastPathComponent

        FileProviderLogger.logAppInformation("WAD文件名称匹配：目标路径: \(path), 父目录路径: \(directoryPath), 无扩展名文件名: \(fileNameWithoutExtension)")

        do {
            // 异步获取当前目录中的所有文件
            let files = try await listFiles(atPath: directoryPath)

            // 遍历文件，寻找匹配的文件名
            for file in files {
                let nsFilePath = file.path as NSString
                let fileName = nsFilePath.deletingPathExtension

                // 匹配文件名
                if fileName == fileNameWithoutExtension {
                    let fileExtension = nsFilePath.pathExtension
                    if fileExtension.isEmpty {
                        FileProviderLogger.logAppInformation("WAD文件名称匹配：匹配成功-文件夹！文件路径: \(file.path), 扩展名: \(fileExtension)")
                    } else {
                        FileProviderLogger.logAppInformation("WAD文件名称匹配：匹配成功-文件！文件路径: \(file.path), 扩展名: \(fileExtension)")
                    }
                    // 提前返回，避免继续无意义的遍历
                    return fileExtension.isEmpty ? nil : "." + fileExtension
                }
            }

            FileProviderLogger.logAppInformation("WAD文件名称匹配：无匹配结果")
        } catch {
            FileProviderLogger.logAppInformation("WAD检测文件扩展名时出错: \(error)，路径 = \(path)")
        }

        return nil // 如果未找到匹配文件，返回 nil
    }

    ///
//    func isDirectory(atPath path: String) -> Bool {
//        var isDirectory: ObjCBool = false
//        let fileManager = FileManager.default
//        return fileManager.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
//    }

    // MARK: - 本地文件操作

    func fileSize(atPath path: String) throws -> Int64 {
        let fileManager = FileManager.default
        let attributes = try fileManager.attributesOfItem(atPath: path)
        guard let fileSize = attributes[FileAttributeKey.size] as? Int64 else {
            throw NSError(domain: "FileSizeErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to retrieve file size."])
        }
        return fileSize
    }

    // 安全的文件路径拼接
    func safeJoinPaths(_ parentPath: String, _ childPath: String) -> String {
        // 确保路径之间有一个路径分隔符
        var adjustedParentPath = parentPath
        var adjustedChildPath = childPath

        // 判断旧路径是否已经包含文件名，避免重复拼接
        if adjustedParentPath.hasSuffix("/" + childPath) {
            return adjustedParentPath
        }

        if !parentPath.hasSuffix("/") {
            adjustedParentPath.append("/")
        }

        if childPath.hasPrefix("/") {
            adjustedChildPath.removeFirst()
        }

        return adjustedParentPath + adjustedChildPath
    }
}
