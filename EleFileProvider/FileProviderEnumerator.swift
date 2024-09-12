//
//  FileProviderEnumerator.swift
//  EleFileProvider
//
//  Created by Bin on 2024/9/12.
//

import FileProvider
import Foundation
import os.log
import WebDavKit

class FileProviderEnumerator: NSObject, NSFileProviderEnumerator {
    private let enumeratedItemIdentifier: NSFileProviderItemIdentifier
    private var anchor: NSFileProviderSyncAnchor
    private let webDAVFileManager: WebDAVFileManager

    init(enumeratedItemIdentifier: NSFileProviderItemIdentifier, webDAVFileManager: WebDAVFileManager) {
        self.enumeratedItemIdentifier = enumeratedItemIdentifier
        self.webDAVFileManager = webDAVFileManager
        anchor = NSFileProviderSyncAnchor(enumeratedItemIdentifier.rawValue.data(using: .utf8)!)
        FileProviderLogger.logAppInformation("WAD测试\(String(describing: type(of: self)))：Enumerating items at path: \(enumeratedItemIdentifier.rawValue)")
        super.init()
    }

    func invalidate() {
        // 清理资源，如果有必要
    }

    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt _: NSFileProviderPage) {
        Task {
            do {
                let path = await webDAVFileManager.pathForIdentifier(enumeratedItemIdentifier)
                FileProviderLogger.logAppInformation("WAD测试\(String(describing: type(of: self)))：Enumerating startingAt items at path: \(path)")

                // 获取当前路径下的所有文件和文件夹
                let files = try await webDAVFileManager.listFiles(atPath: path)
                FileProviderLogger.logAppInformation("WAD测试\(String(describing: type(of: self))) 遍历enumerateItems: \(files)")
                // 为每个文件生成独立的 NSFileProviderItemIdentifier
                let items = files.map { file in
                    let itemIdentifier = webDAVFileManager.identifierForPath(file.path)
                    let fileItem = FileProviderItem(file: file, identifier: itemIdentifier)
                    FileProviderLogger.logAppInformation("WAD测试\(String(describing: type(of: self)))：循环后为每个文件生成独立的 NSFileProviderItemIdentifier: \(itemIdentifier),此时父类标签：\(fileItem.parentItemIdentifier)")
                    return fileItem
                }

                FileProviderLogger.logAppInformation("WAD测试\(String(describing: type(of: self)))：Enumerated items: \(items.map { $0.itemIdentifier.rawValue })")
                observer.didEnumerate(items)
                FileProviderLogger.logAppInformation("WAD测试\(String(describing: type(of: self)))：已执行 observer.didEnumerate")
                observer.finishEnumerating(upTo: nil)
                FileProviderLogger.logAppInformation("WAD测试\(String(describing: type(of: self)))：已执行 observer.finishEnumerating")
            } catch {
                FileProviderLogger.logAppInformation("WAD测试\(String(describing: type(of: self)))：Error enumerating items: \(error)")
                observer.finishEnumerating(upTo: nil)
            }
        }
    }

    func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
        Task {
            do {
                let path = await webDAVFileManager.pathForIdentifier(enumeratedItemIdentifier)
                let files = try await webDAVFileManager.listFiles(atPath: path)

                // 创建一个新的同步锚点
                let newAnchor = generateSyncAnchor(for: files)
                saveCurrentFileState(files, for: newAnchor)

                // 通知系统的变化
                var itemsToReport: [NSFileProviderItem] = []
                for file in files {
                    let itemIdentifier = webDAVFileManager.identifierForPath(file.path)
                    let updatedItem = FileProviderItem(file: file, identifier: itemIdentifier)
                    itemsToReport.append(updatedItem)
                }

                // 通过 observer 报告变化
                observer.finishEnumeratingChanges(upTo: newAnchor, moreComing: false)
//                   // 此处假设有机制报告单个文件变化
//                   for item in itemsToReport {
//                       // 需要实现 notifyObserver(of:with:) 方法来报告具体的变化
//                       notifyObserver(of: item, with: .modified)
//                   }
            } catch {
                FileProviderLogger.logAppInformation("WAD测试：Error enumerating changes: \(error)")
                observer.finishEnumeratingChanges(upTo: anchor, moreComing: false)
            }
        }
    }

    func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        Task {
            do {
                let path = await webDAVFileManager.pathForIdentifier(enumeratedItemIdentifier)
                let files = try await webDAVFileManager.listFiles(atPath: path)

                let newAnchor = generateSyncAnchor(for: files)
                self.anchor = newAnchor
                saveCurrentFileState(files, for: newAnchor)

                completionHandler(newAnchor)
            } catch {
                FileProviderLogger.logAppInformation("WAD测试：Error fetching sync anchor: \(error)")
                completionHandler(nil)
            }
        }
    }

    // 辅助方法

    private func generateSyncAnchor(for files: [WebDAVFile]) -> NSFileProviderSyncAnchor {
        let anchorData = "\(enumeratedItemIdentifier.rawValue)_\(files.count)_\(Date().timeIntervalSince1970)".data(using: .utf8)!
        return NSFileProviderSyncAnchor(anchorData)
    }

    private func saveCurrentFileState(_ files: [WebDAVFile], for anchor: NSFileProviderSyncAnchor) {
        // 将 anchor.rawValue 编码为 Base64 字符串
        let anchorString = anchor.rawValue.base64EncodedString()

        let fileState: [String: Any] = [
            "anchor": anchorString, // 使用 Base64 编码字符串
            "files": files.map { file in
                [
                    "path": file.path,
                    "lastModified": file.lastModified.timeIntervalSince1970,
                    "size": file.size,
                ]
            },
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: fileState, options: .prettyPrinted)
            let filePath = getFilePath(for: anchor)
            try jsonData.write(to: URL(fileURLWithPath: filePath))
        } catch {
            FileProviderLogger.logAppInformation("Error saving file state: \(error)")
        }
    }

    private func loadPreviousFileState(for anchor: NSFileProviderSyncAnchor) throws -> [WebDAVFile] {
        let filePath = getFilePath(for: anchor)

        guard let jsonData = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            return []
        }

        guard let fileState = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any],
              let anchorString = fileState["anchor"] as? String,
              let filesArray = fileState["files"] as? [[String: Any]]
        else {
            return []
        }

        let loadedAnchor = NSFileProviderSyncAnchor(Data(base64Encoded: anchorString)!)

        // 检查是否与当前 anchor 匹配
        guard loadedAnchor == anchor else {
            return []
        }

        return filesArray.compactMap { dict in
            guard let path = dict["path"] as? String,
                  let lastModifiedTimestamp = dict["lastModified"] as? TimeInterval,
                  let size = dict["size"] as? Int64
            else {
                return nil
            }

            let lastModified = Date(timeIntervalSince1970: lastModifiedTimestamp)
            return WebDAVFile(path: path, lastModified: lastModified, size: size, isDirectory: false, auth: nil, cookie: nil)
        }
    }

    private func getFilePath(for anchor: NSFileProviderSyncAnchor) -> String {
        // 根据同步锚点生成文件路径
        let anchorString = anchor.rawValue.base64EncodedString()
        let fileName = "\(anchorString).json"
        let directoryPath = FileManager.default.temporaryDirectory.path
        return (directoryPath as NSString).appendingPathComponent(fileName)
    }
}
