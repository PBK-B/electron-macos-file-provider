import FileProvider
import Foundation
import os.log
import UniformTypeIdentifiers
import WebDavKit

let logger = Logger(subsystem: "com.example.myapp", category: "FileProviderExtension")
// 存储参数的键
private let urlKey = "storedURL"
private let cookieKey = "storedCookie"
class FileProviderExtension: NSObject, NSFileProviderReplicatedExtension {
    let domain: NSFileProviderDomain
    var manager: NSFileProviderManager

    public var webDAVFileManager: WebDAVFileManager? {
        if let groupUserDefaults = UserDefaults(suiteName: "groups.cloud.lazycat.clients"){
            if let fileProviderURL = groupUserDefaults.string(forKey: "FileProviderURL"),
               let cookie = groupUserDefaults.string(forKey: "FileProviderCookie")
            {
                FileProviderLogger.logAppInformation("WAD|链接：\(fileProviderURL) \(cookie)")
                let webDAV = WebDAV(baseURL: fileProviderURL, port: 443, cookie: cookie)
                return WebDAVFileManager(webDAV: webDAV)
            }
        }
        FileProviderLogger.logAppInformation("WAD|错误：group.com.webdav.fjs group取值失败")
        return nil
    }

    required init(domain: NSFileProviderDomain) {
        self.domain = domain
        manager = NSFileProviderManager(for: domain)!
        super.init()
        // 发送请求
        fetchServerPortInfo()

        let webdavProvider = webDAVFileManager
        FileProviderLogger.logAppInformation("WAD测试\(String(describing: type(of: self)))：[FileProviderExtension] Initialized with domain: \(domain.identifier.rawValue)")
        FileProviderLogger.logAppInformation("WAD测试\(String(describing: type(of: self)))：[FileProviderExtension] WebDAVManager: \(String(describing: webdavProvider))")
        FileProviderLogger.logAppInformation("初始化")
        logger.debug("初始化")
    }

    func invalidate() {}

    func startProvidingItem(at url: URL, completionHandler: @escaping ((Error?) -> Void)) {
        FileProviderLogger.logAppInformation("URL拓展：拓展处理")
        // 检查 URL 是否符合预期的 URL Scheme
        if url.scheme == "myfileprovider" {
            let message = url.queryParameters?["message"] ?? "No message"
            FileProviderLogger.logAppInformation("URL：Received message from main app: \(message)")
        }
        completionHandler(nil)
    }

    func item(for identifier: NSFileProviderItemIdentifier, request _: NSFileProviderRequest, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) -> Progress {
        let progress = Progress()
        guard let webDAVFileManager = webDAVFileManager else {
            FileProviderLogger.logAppInformation("WAD测试\(String(describing: type(of: self)))：WebDAVFileManager is nil, returning error.")
            completionHandler(nil, NSError(domain: NSFileProviderError.domain, code: NSFileProviderError.Code.notFound.rawValue, userInfo: nil))
            return progress
        }
        Task {
            do {
                // 获取路径
                let path = await webDAVFileManager.pathForIdentifier(identifier)
                FileProviderLogger.logAppInformation("WAD测试\(String(describing: type(of: self)))： item for 方法返回的：identifier \(identifier.rawValue), 转化后的Path: \(path)")

                guard !path.isEmpty else {
                    FileProviderLogger.logAppInformation("WAD测试\(String(describing: type(of: self)))：Path is empty, returning error.")
                    completionHandler(nil, NSError(domain: NSFileProviderError.domain, code: NSFileProviderError.Code.notFound.rawValue, userInfo: nil))
                    return
                }
                // 是否目录
                let isDirectory = try await webDAVFileManager.isDirectory(atPath: path)
                let newIdentifier = webDAVFileManager.identifierForPath(path)
                FileProviderLogger.logAppInformation("WAD测试: 判断路径 \(path) 是目录：\(isDirectory)，此时生成的标签ID是\(newIdentifier)")
                let files = try await webDAVFileManager.listFiles(atPath: path)
                FileProviderLogger.logAppInformation("WAD测试: 在路径 \(path) 下找到的文件: \(files.count)个")
                FileProviderLogger.logAppInformation("WAD测试: 在路径 \(path) 下找到的文件: \(files.map { $0.path }.joined(separator: ", "))")
                if isDirectory {
                    // 如果是目录但目录为空，返回一个代表空目录的对象
                    guard !files.isEmpty else {
                        FileProviderLogger.logAppInformation("WAD测试: 空目录 \(path)，返回一个空的FileProviderItem")
                        let emptyDirectoryItem = FileProviderItem(file: WebDAVFile(path: path, lastModified: Date(), size: 0, isDirectory: true)!, identifier: newIdentifier)
                        completionHandler(emptyDirectoryItem, nil)
                        return
                    }
                    // 是目录则返回代表目录的信息
                    let directoryItem = FileProviderItem(file: WebDAVFile(path: path, lastModified: Date(), size: 0, isDirectory: true)!, identifier: identifier)
                    completionHandler(directoryItem, nil)
                } else {
                    // 如果是单个文件需要匹配
                    let normalizePath = path.hasPrefix("/") ? String(path.dropFirst()) : path
                    if let matchedFile = files.first(where: { $0.path == normalizePath }) {
                        let fileItem = FileProviderItem(file: matchedFile, identifier: newIdentifier)
                        FileProviderLogger.logAppInformation("WAD测试: 返回匹配的文件: \(fileItem.filename)")
                        completionHandler(fileItem, nil)
                    } else {
                        FileProviderLogger.logAppInformation("WAD错误: 未找到匹配的文件，返回错误 当前files = \(files), path = \(path)")
                        completionHandler(nil, NSError(domain: NSFileProviderError.domain, code: NSFileProviderError.Code.notFound.rawValue, userInfo: nil))
                    }
                }
            } catch {
                FileProviderLogger.logAppInformation("WAD错误\(String(describing: type(of: self)))：Error fetching item: \(error) identifier \(identifier.rawValue)")
                completionHandler(nil, error)
            }
        }

        FileProviderLogger.logAppInformation("WAD测试\(String(describing: type(of: self)))：item(for）返回progress")
        return progress
    }

    func fetchContents(for itemIdentifier: NSFileProviderItemIdentifier, version _: NSFileProviderItemVersion?, request _: NSFileProviderRequest, completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void) -> Progress {
        let progress = Progress()

        Task {
            do {
                guard let webDAVFileManager = webDAVFileManager else {
                    FileProviderLogger.logAppInformation("WAD测试：WebDAVFileManager is nil, returning error.")
                    completionHandler(nil, nil, NSError(domain: NSFileProviderError.domain, code: NSFileProviderError.Code.unavailable.rawValue, userInfo: nil))
                    return
                }

                let path = await webDAVFileManager.pathForIdentifier(itemIdentifier)
                FileProviderLogger.logAppInformation("WAD测试：Fetching contents for item \(itemIdentifier.rawValue) at path: \(path)")

                // 确保路径有效
                guard !path.isEmpty else {
                    FileProviderLogger.logAppInformation("WAD测试：Path is empty, returning error.")
                    completionHandler(nil, nil, NSError(domain: NSFileProviderError.domain, code: NSFileProviderError.Code.notFound.rawValue, userInfo: nil))
                    return
                }

                // 检查文件是否存在
                let fileExists = try await webDAVFileManager.fileExists(atPath: path)
                if !fileExists {
                    FileProviderLogger.logAppInformation("WAD测试：File does not exist at path: \(path)")
                    completionHandler(nil, nil, NSError(domain: NSFileProviderError.domain, code: NSFileProviderError.Code.notFound.rawValue, userInfo: nil))
                    return
                }

                FileProviderLogger.logAppInformation("WAD测试：开始下载 \(path)")
                let tempURL = try await webDAVFileManager.downloadFile(atPath: path)
                let tempDirectoryPath = tempURL.deletingLastPathComponent()
                // 创建临时目录
                if !FileManager.default.fileExists(atPath: tempDirectoryPath.path) {
                    try FileManager.default.createDirectory(at: tempDirectoryPath, withIntermediateDirectories: true, attributes: nil)
                    FileProviderLogger.logAppInformation("WAD测试:临时目录不存在，强创一次 \(tempURL)")
                }
                FileProviderLogger.logAppInformation("WAD测试：下载完成，写临时文件")
                // 获取文件大小
                let fileSize = try webDAVFileManager.fileSize(atPath: tempURL.path)
                // 创建 FileProviderItem 实例
                let webdavFile = WebDAVFile(path: path, lastModified: Date(), size: fileSize, isDirectory: false, auth: nil, cookie: nil)
                let fileItem = FileProviderItem(file: webdavFile!, identifier: itemIdentifier)
                FileProviderLogger.logAppInformation("WAD测试：Contents fetched and written to: \(tempURL)")
                completionHandler(tempURL, fileItem, nil) // 返回 URL 和文件项
            } catch {
                FileProviderLogger.logAppInformation("WAD测试：Error fetching contents: \(error)")
                completionHandler(nil, nil, error) // 返回错误
            }
        }

        return progress
    }

    // 新建文件
    func createItem(basedOn itemTemplate: NSFileProviderItem, fields: NSFileProviderItemFields, contents url: URL?, options _: NSFileProviderCreateItemOptions = [], request _: NSFileProviderRequest, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) -> Progress {
        let progress = Progress()
        FileProviderLogger.logAppInformation("WAD测试\(String(describing: type(of: self)))：新建item")

        Task {
            do {
                guard let webDAVFileManager = webDAVFileManager else {
                    FileProviderLogger.logAppInformation("WAD测试\(String(describing: type(of: self)))：WebDAVFileManager is nil, returning error.")
                    return
                }

                let name = itemTemplate.filename
                let parentFolder = await webDAVFileManager.pathForIdentifier(itemTemplate.parentItemIdentifier)
                // 获取要创建的路径
                let path = webDAVFileManager.safeJoinPaths(parentFolder, name)
                // 创建一个标识符
                let newIdentifier = webDAVFileManager.identifierForPath(path)
                // 判断新建的是文件还是文件夹
                if itemTemplate.contentType == UTType.folder {
                    // 新建文件夹
                    FileProviderLogger.logAppInformation("WAD测试：创建新文件夹在路径 \(path)")
                    let creatResult = try await webDAVFileManager.createFolder(atPath: path)
                    if creatResult {
                        let newFolder = WebDAVFile(
                            path: path,
                            lastModified: Date(),
                            size: 0,
                            isDirectory: true,
                            auth: nil,
                            cookie: nil
                        )

                        let newItem = FileProviderItem(file: newFolder!, identifier: newIdentifier)
                        FileProviderLogger.logAppInformation("WAD测试：文件夹创建成功")
                        completionHandler(newItem, fields, true, nil)
                    } else {
                        FileProviderLogger.logAppInformation("WAD服务器报错：文件夹创建失败")
                    }
                } else if let url = url {
                    // 新建文件
                    let data = try Data(contentsOf: url)
                    FileProviderLogger.logAppInformation("WAD测试：上传新文件到路径 \(path)")

                    let uploadStatus = try await webDAVFileManager.uploadFile(atPath: path, data: data)
                    if uploadStatus {
                        let newFile = WebDAVFile(
                            path: path,
                            lastModified: Date(),
                            size: Int64(data.count),
                            isDirectory: false,
                            auth: nil,
                            cookie: nil
                        )

                        let newItem = FileProviderItem(file: newFile!, identifier: newIdentifier)
                        FileProviderLogger.logAppInformation("WAD测试：wad服务器上文件创建成功")
                        completionHandler(newItem, fields, true, nil)
                    } else {
                        FileProviderLogger.logAppInformation("WAD测试：Error creating file")
                        completionHandler(nil, [], false, nil)
                    }
                } else {
                    FileProviderLogger.logAppInformation("WAD测试：Error creating item, missing file URL")
                    completionHandler(nil, [], false, nil)
                }
            } catch {
                FileProviderLogger.logAppInformation("WAD测试：Error creating item: \(error)")
                completionHandler(nil, [], false, error)
            }
        }
        return progress
    }

    actor RenameManager {
        private var ongoingRenames: [NSFileProviderItemIdentifier: Bool] = [:]

        func isRenameInProgress(for identifier: NSFileProviderItemIdentifier) -> Bool {
            return ongoingRenames[identifier] ?? false
        }

        func startRename(for identifier: NSFileProviderItemIdentifier) {
            ongoingRenames[identifier] = true
        }

        func finishRename(for identifier: NSFileProviderItemIdentifier) {
            ongoingRenames[identifier] = false
        }
    }

    let renameManager = RenameManager()
    private let renameQueue = DispatchQueue(label: "com.example.fileprovider.renameQueue", attributes: .concurrent)
    func modifyItem(_ item: NSFileProviderItem, baseVersion _: NSFileProviderItemVersion, changedFields: NSFileProviderItemFields, contents newContents: URL?, options _: NSFileProviderModifyItemOptions = [], request _: NSFileProviderRequest, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) -> Progress {
        let progress = Progress()
        FileProviderLogger.logAppInformation("WAD测试：modifyItem called with fields: \(String(describing: changedFields))")

        guard let webDAVFileManager = webDAVFileManager else {
            FileProviderLogger.logAppInformation("WAD测试：WebDAVFileManager is nil, returning error.")
            let error = NSError(domain: NSFileProviderError.domain, code: NSFileProviderError.Code.unavailable.rawValue, userInfo: nil)
            completionHandler(nil, [], false, error)
            return Progress()
        }

        Task {
            do {
                // 获取旧文件的路径
                let oldPath = await webDAVFileManager.pathForIdentifier(item.itemIdentifier)
                FileProviderLogger.logAppInformation("WAD测试：Modifying item at oldPath: \(oldPath)")

                // 处理重命名操作
                if changedFields.contains(.filename) || changedFields.contains(.parentItemIdentifier) {
                    // 检查是否已经有重命名操作在进行
                    if await renameManager.isRenameInProgress(for: item.itemIdentifier) {
                        FileProviderLogger.logAppInformation("Rename operation already in progress for \(item.itemIdentifier), skipping.")
                        completionHandler(item, changedFields, true, nil)
                        return
                    }
                    // 标记重命名操作为进行中
                    await renameManager.startRename(for: item.itemIdentifier)
                    defer {
                        // 完成重命名操作
                        Task {
                            await renameManager.finishRename(for: item.itemIdentifier)
                        }
                    }
                    let oldDirectory = (oldPath as NSString).deletingLastPathComponent
                    let newFilename = item.filename
                    let newPath = (oldDirectory as NSString).appendingPathComponent(newFilename)

                    // 检查新文件是否已经存在（避免重命名到一个已经存在的文件）
                    let newFileExists = try await webDAVFileManager.fileExists(atPath: newPath)
                    if newFileExists {
                        let newFiles = try await webDAVFileManager.listFiles(atPath: newPath)
                        if let newFile = newFiles.first {
                            // 明确告知系统文件操作已经完成，并更新状态
                            let updatedFileItem = FileProviderItem(file: newFile, identifier: webDAVFileManager.identifierForPath(newPath))
                            completionHandler(updatedFileItem, [], true, nil)
                            FileProviderLogger.logAppInformation("新文件路径已经存在: \(newPath)，直接更新本地文件显示状态")
                        } else {
                            let updatedFileItem = FileProviderItem(file: WebDAVFile(path: newPath, lastModified: Date(), size: 0, isDirectory: true)!, identifier: webDAVFileManager.identifierForPath(newPath))
                            FileProviderLogger.logAppInformation("新文件路径已经存在空文件夹: \(newPath)，直接更新本地文件显示状态")
                            completionHandler(updatedFileItem, [], true, nil)
                        }
                        return
                    }

                    // 检查旧文件是否存在
                    let oldFileExists = try await webDAVFileManager.fileExists(atPath: oldPath)
                    if !oldFileExists {
                        return
                    }

                    FileProviderLogger.logAppInformation("WAD测试：开始重命名 \(oldPath) to \(newPath).")
                    do {
                        let renameSuccess = try await webDAVFileManager.moveFile(fromPath: oldPath, toPath: newPath)
                        FileProviderLogger.logAppInformation("WAD测试：Modifying item oldPAth: \(oldPath) to Newpath: \(newPath) 是否成功: \(renameSuccess)")
                        if renameSuccess {
                            FileProviderLogger.logAppInformation("WAD测试：Item successfully renamed to \(newPath).")
                            let newIdentifier = NSFileProviderItemIdentifier(newPath)
                            let newFiles = try await webDAVFileManager.listFiles(atPath: newPath)
                            if let newFile = newFiles.first {
                                let newItem = FileProviderItem(
                                    file: newFile,
                                    identifier: newIdentifier
                                )
                                completionHandler(newItem, [], true, nil)
                            } else {
                                FileProviderLogger.logAppInformation("WAD|ERROR：DAV文件不存在：Failed to rename item.")
                                let error = NSError(domain: NSFileProviderError.domain, code: NSFileProviderError.Code.unavailable.rawValue, userInfo: nil)
                                completionHandler(nil, [], false, error)
                            }
                        } else {
                            FileProviderLogger.logAppInformation("WAD|ERROR：DAV接口报错Failed to rename item.")
                            let error = NSError(domain: NSFileProviderError.domain, code: NSFileProviderError.Code.unavailable.rawValue, userInfo: nil)
                            completionHandler(nil, [], false, error)
                        }
                    } catch {
                        FileProviderLogger.logAppInformation("WAD|ERROR：Rename operation failed with error: \(error)")
                        completionHandler(nil, [], false, error)
                    }
                } else {
                    let fileName = item.filename
                    // 安全拼接路径，确保正确的路径格式
                    let fullPath = webDAVFileManager.safeJoinPaths(oldPath, fileName)
                    FileProviderLogger.logAppInformation("WADC测试：开始处理文件内容的修改 路径是\(fullPath)")
                    // 处理文件内容的修改
                    if let newContents = newContents {
                        // 读取新文件的内容
                        let data = try Data(contentsOf: newContents)

                        // 上传到 WebDAV
                        let uploadSuccess = try await webDAVFileManager.uploadFile(atPath: fullPath, data: data)
                        if uploadSuccess {
                            FileProviderLogger.logAppInformation("WAD测试：Item successfully modified and uploaded to WebDAV.")
                            let newItem = FileProviderItem(file: WebDAVFile(path: oldPath, lastModified: Date(), size: Int64(data.count), isDirectory: false, auth: nil, cookie: nil)!, identifier: item.itemIdentifier)
                            completionHandler(newItem, [], true, nil)
                        } else {
                            FileProviderLogger.logAppInformation("WAD错误：Failed to upload modified item to WebDAV.")
                            let error = NSError(domain: NSFileProviderError.domain, code: NSFileProviderError.Code.unavailable.rawValue, userInfo: nil)
                            completionHandler(nil, [], false, error)
                        }
                    } else {
                        FileProviderLogger.logAppInformation("WAD错误：No new content provided, 返回老状态")
                        // 没有提供新的内容，返回成功状态，但不执行任何修改
                        let newItem = FileProviderItem(file: WebDAVFile(path: oldPath, lastModified: Date(), size: 0, isDirectory: false, auth: nil, cookie: nil)!, identifier: item.itemIdentifier)
                        completionHandler(newItem, [], false, nil) // 返回成功状态，文件未更改
                    }
                }
            } catch {
                FileProviderLogger.logAppInformation("WAD测试：Error modifying item: \(error)")
                completionHandler(nil, [], false, error)
            }
        }

        return progress
    }

    func deleteItem(identifier: NSFileProviderItemIdentifier, baseVersion _: NSFileProviderItemVersion, options _: NSFileProviderDeleteItemOptions = [], request _: NSFileProviderRequest, completionHandler: @escaping (Error?) -> Void) -> Progress {
        let progress = Progress()
        Task {
            do {
                guard let webDAVFileManager = webDAVFileManager else {
                    FileProviderLogger.logAppInformation("WAD测试\(String(describing: type(of: self)))：WebDAVFileManager is nil, returning error.")
                    completionHandler(NSError(domain: NSFileProviderError.domain, code: NSFileProviderError.Code.unavailable.rawValue, userInfo: nil))
                    return
                }

                let path = await webDAVFileManager.pathForIdentifier(identifier)
                FileProviderLogger.logAppInformation("WAD测试\(String(describing: type(of: self)))：Deleting item with identifier \(identifier.rawValue) at path: \(path)")

                let success = try await webDAVFileManager.deleteFile(atPath: path)
                if success {
                    FileProviderLogger.logAppInformation("WAD测试\(String(describing: type(of: self)))：Item deleted successfully.")
                    completionHandler(nil)
                } else {
                    FileProviderLogger.logAppInformation("WAD测试\(String(describing: type(of: self)))：Failed to delete item.")
                    completionHandler(NSError(domain: NSFileProviderError.domain, code: NSFileProviderError.Code.unavailable.rawValue, userInfo: nil))
                }
            } catch {
                FileProviderLogger.logAppInformation("WAD测试\(String(describing: type(of: self)))：Error deleting item: \(error)")
                completionHandler(error)
            }
        }
        return progress
    }

    func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier, request _: NSFileProviderRequest) throws -> NSFileProviderEnumerator {
        FileProviderLogger.logAppInformation("WAD测试\(String(describing: type(of: self)))：Creating enumerator for container with identifier \(containerItemIdentifier.rawValue)")

        guard let webDAVFileManager = webDAVFileManager else {
            FileProviderLogger.logAppInformation("WAD|Error\(String(describing: type(of: self)))：Creating enumerator 异常")
            throw NSError(domain: NSFileProviderError.domain, code: NSFileProviderError.Code.unavailable.rawValue, userInfo: [NSLocalizedDescriptionKey: "WebDAV connection not established"])
        }

        // 规范化路径，去除多余的斜杠
        let sanitizedIdentifier = containerItemIdentifier.rawValue.replacingOccurrences(of: "//", with: "/")
        let sanitizedItemIdentifier = NSFileProviderItemIdentifier(sanitizedIdentifier)

        return FileProviderEnumerator(enumeratedItemIdentifier: sanitizedItemIdentifier, webDAVFileManager: webDAVFileManager)
    }

    //    func providePlaceholder(at url: URL, completionHandler: @escaping (Error?) -> Void) -> Progress {
    //        let progress = Progress()
    //        DispatchQueue.global().async {
    //            do {
    //                let placeholderContent = self.generatePlaceholderContent(for: url)
    //                try placeholderContent.write(to: url)
    //                FileProviderLogger.logAppInformation("WAD测试\(String(describing: type(of: self)))：Placeholder provided at: \(url)")
    //                completionHandler(nil)
    //            } catch {
    //                FileProviderLogger.logAppInformation("WAD测试\(String(describing: type(of: self)))：Error providing placeholder at \(url): \(error)")
    //                completionHandler(error)
    //            }
    //        }
    //        return progress
    //    }

//    func generatePlaceholderContent(for url: URL) -> Data {
//        var placeholderInfo = [String: Any]()
//        placeholderInfo["FileName"] = url.lastPathComponent
//        placeholderInfo["CreationDate"] = Date()
//        placeholderInfo["Size"] = 0 // 设置为 0 或适当的占位大小
//
//        do {
//            let jsonData = try JSONSerialization.data(withJSONObject: placeholderInfo, options: .prettyPrinted)
//            return jsonData
//        } catch {
//            return Data() // 如果序列化失败，返回空数据
//        }
//    }

    func supportedServiceSources(for _: NSFileProviderItemIdentifier) -> [NSFileProviderServiceSource] {
        FileProviderLogger.logAppInformation("xpc:返回自定义服务")
        // 返回自定义服务
        let name = NSFileProviderServiceName("com.example.MyXPCService")
        return [MyCustomFileProviderService(serviceName: name)]
    }

    func beginRequest(with _: NSFileProviderRequest) {
        FileProviderLogger.logAppInformation("xpc:Initialize XPC service")
        let serviceName = NSFileProviderServiceName("com.example.MyXPCService")
        let fileProviderService = MyCustomFileProviderService(serviceName: serviceName)
    }
}

private extension String {
    func base64Decoded() -> String? {
        guard let data = Data(base64Encoded: self) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func user() -> String? {
        let parts = components(separatedBy: ":")
        return parts.count > 1 ? parts[0] : nil
    }

    func password() -> String? {
        let parts = components(separatedBy: ":")
        return parts.count > 1 ? parts[1] : nil
    }
}

// NSFileProviderError 的自定义实现
enum NSFileProviderError {
    static let domain = "NSFileProviderErrorDomain"

    enum Code: Int {
        case notFound = 1
        case unavailable = 2
        case unsupported = 3
    }
}

extension NSFileProviderItemIdentifier {
    // 创建一个方法来根据文件路径生成 NSFileProviderItemIdentifier。
    static func fromPath(_ path: String) -> NSFileProviderItemIdentifier {
        return NSFileProviderItemIdentifier(path)
    }
}

extension URL {
    var queryParameters: [String: String]? {
        var params = [String: String]()
        let queryItems = URLComponents(url: self, resolvingAgainstBaseURL: false)?.queryItems
        queryItems?.forEach { item in
            params[item.name] = item.value
        }
        return params
    }
}

// func sendMessageToMainProcess() {
//    let url = URL(string: "http://127.0.0.1:9999")!
//    let task = URLSession.shared.dataTask(with: url) { data, response, error in
//        if let error = error {
//            FileProviderLogger.logAppInformation("Error: \(error)")
//        } else if let data = data {
//            do {
//                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String] {
//                    FileProviderLogger.logAppInformation("附属进程接收：\(jsonResponse)")
//                    let url = jsonResponse["URL"] ?? "Unknown URL"
//                    let cookie = jsonResponse["Cookie"] ?? "No Cookie"
//                    storeParameter(url: url, cookie: cookie)
//                }
//            } catch {
//                FileProviderLogger.logAppInformation("Error parsing JSON: \(error)")
//            }
//        }
//    }
//    task.resume()
// }

// 动态端口写法
func fetchServerPortInfo() {
    let portFileURL = URL(fileURLWithPath: "/tmp/server_port.txt")

    // 读取端口文件
    do {
        let portString = try String(contentsOf: portFileURL, encoding: .utf8)
        let port = portString.replacingOccurrences(of: "Port: ", with: "")

        let serverInfoURL = URL(string: "http://localhost:\(port)/server-info")!

        // 创建请求
        let request = URLRequest(url: serverInfoURL)

        // 使用 URLSession 发起请求
        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                print("Error fetching server info: \(error)")
                return
            }

            guard let data = data else {
                print("No data received")
                return
            }

            do {
                if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String] {
                    let url = jsonObject["URL"] ?? "Unknown URL"
                    let cookie = jsonObject["Cookie"] ?? "No Cookie"
                    storeParameter(url: url, cookie: cookie)
                } else {
                    print("Error parsing JSON")
                }
            } catch {
                print("JSON parsing error: \(error)")
            }
        }

        // 启动任务
        task.resume()
    } catch {
        print("Error reading port file: \(error)")
    }
}

// 储存参数
private func storeParameter(url: String, cookie: String) {
    UserDefaults.standard.set(url, forKey: "FileProviderURL")
    UserDefaults.standard.set(cookie, forKey: "FileProviderCookie")
    FileProviderLogger.logAppInformation("Stored URL: \(url)")
    FileProviderLogger.logAppInformation("Stored Cookie: \(cookie)")
}
