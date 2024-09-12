//
//  FileProviderItem.swift
//  EleFileProvider
//
//  Created by Bin on 2024/9/12.
//
import FileProvider
import Foundation
import os.log
import UniformTypeIdentifiers
import WebDavKit

// 实现 NSFileProviderItem 协议的文件项类
class FileProviderItem: NSObject, NSFileProviderItem {
    // WebDAVFile 实例，包含文件或目录的详细信息
    private let file: WebDAVFile
    var itemIdentifier: NSFileProviderItemIdentifier

    // 初始化方法，使用 WebDAVFile 实例来创建 FileProviderItem
    init(file: WebDAVFile, identifier: NSFileProviderItemIdentifier) {
        self.file = file
        itemIdentifier = identifier
        super.init()
    }

    // 返回文件项的父级标识符，基于 WebDAVFile 的路径
    var parentItemIdentifier: NSFileProviderItemIdentifier {
        var parentPath: NSFileProviderItemIdentifier = .rootContainer
        if var url = URL(string: file.path), url.pathComponents.count > 1 {
            url.deleteLastPathComponent()

            // 确保路径不以双斜杠开头
            let cleanPath = url.path.hasPrefix("/") ? url.path : "/" + url.path

            if cleanPath != "/" {
                parentPath = NSFileProviderItemIdentifier(cleanPath)
            }

            if url.pathComponents.first == ".Trash" {
                parentPath = .trashContainer
            }
        }
        FileProviderLogger.logAppInformation("WAD测试\(String(describing: type(of: self)))：父类标识：\(String(describing: parentPath)),此时子类标识：\(String(describing: itemIdentifier))")
        return parentPath
    }

    // 文件项的能力，基于 WebDAVFile 是否是目录
    var capabilities: NSFileProviderItemCapabilities {
        var capabilities: NSFileProviderItemCapabilities = [.allowsReading]
        if file.isDirectory {
            capabilities.formUnion([.allowsWriting, .allowsReparenting])
        } else {
            capabilities.formUnion([.allowsWriting, .allowsRenaming, .allowsDeleting])
        }
        return capabilities
    }

    // 文件项的版本信息，使用文件的最后修改时间和 ID 生成
    var itemVersion: NSFileProviderItemVersion {
        // 将 lastModified 时间转换为字符串，然后转换为 Data
        let contentVersion = "\(file.lastModified.timeIntervalSince1970)".data(using: .utf8)!
        // 使用文件 ID 作为元数据版本
        let metadataVersion = file.id.data(using: .utf8)!
        return NSFileProviderItemVersion(contentVersion: contentVersion, metadataVersion: metadataVersion)
    }

    // 文件名，基于 WebDAVFile 的路径
    var filename: String {
        return file.fileName
    }

    // 文件类型，基于 WebDAVFile 是否是目录或文件
//    var contentType: UTType {
//        // 如果是目录，返回 .folder 类型
//        // 否则，尝试根据文件扩展名获取 UTType，如果无法确定，返回 .data
//        let _type = file.isDirectory ? .folder : UTType(filenameExtension: file.extension) ?? .data
//        FileProviderLogger.logAppInformation("WAD测试\(String(describing: type(of: self)))：contentType名：\(_type)")
//        return _type
//    }

    // 文件类型，基于 WebDAVFile 是否是目录或文件
    var contentType: UTType {
        // 如果是目录，返回 .folder 类型
        var _type: UTType = .folder
        if file.isDirectory {
            _type = .folder
        } else if let type = UTType(filenameExtension: file.extension) {
            // 检查是否是源代码类型，如果是，返回相应的类型
            if type.conforms(to: .sourceCode) {
                _type = .sourceCode
            } else {
                _type = type
            }
        } else {
            // 默认返回 .data 类型
            _type = .data
        }
        FileProviderLogger.logAppInformation("WAD测试\(String(describing: type(of: self)))：contentType名：\(_type),此时ID = \(itemIdentifier),filePath = \(file.path),此时文件名 ：\(file.fileName)，是否目录：\(file.isDirectory)")
        return _type
    }

    var documentSize: NSNumber? {
        return file.size as NSNumber
    }

//    var childItemCount: NSNumber? {
//        return 0
//    }

    // 公开的属性，允许外部访问 file 的属性
    var size: Int64 {
        return file.size
    }

    var isDirectory: Bool {
        return file.isDirectory
    }
}
