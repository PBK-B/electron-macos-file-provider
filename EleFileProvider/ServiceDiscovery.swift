import Foundation
import Network

class ServiceDiscovery: NSObject {
    private var browser: NWBrowser?

    override init() {
        super.init()
        startBrowsing()
    }

    private let ServiceName = "MyServiceForFileProvider"
    private let ServiceType = "_http._tcp"
    private func startBrowsing() {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = false
        // 创建 NWBrowser 实例
        let descriptor: NWBrowser.Descriptor
//        if #available(macOS 13.0, *) {
//            descriptor = .applicationService(name: self.ServiceName)
//        } else {
//            descriptor = .bonjour(type: self.ServiceType, domain: nil)
//        }

        descriptor = .bonjour(type: ServiceType, domain: nil)

        browser = NWBrowser(for: descriptor, using: parameters)

        // 处理浏览器状态更新
        browser?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("Service discovery is ready")
            case let .failed(error):
                print("Service discovery failed with error: \(error)")
            default:
                break
            }
        }

        // 处理服务结果变化
        browser?.browseResultsChangedHandler = { results, _ in
            print("Services changed: \(results.count) results found.")
            for result in results {
                self.handleBrowserResult(result)
            }
        }

        // 启动浏览器
        browser?.start(queue: .main)
    }

    private func handleBrowserResult(_ result: NWBrowser.Result) {
        // 获取 endpoint
        switch result.endpoint {
        case let .service(name, type, domain, interface):
            // 检查是否是你想要的服务
            if name == ServiceName && type == ServiceType {
                print("Found MyServiceForFileProvider!")
                // 这里可以进行你想要的服务操作，比如连接服务或提取相关信息
                print("Service name: \(name), type: \(type), domain: \(domain)")
            } else {
                print("Unsupported service: \(name)")
            }

        default:
            print("Unsupported endpoint type: \(result.endpoint)")
        }
    }

    private func handleServiceDiscovery(_ endpoint: NWEndpoint) {
        switch endpoint {
        case let .hostPort(host, port):
            // 处理主机和端口
            let serviceInfoURL = "http://\(host):\(port)"
            fetchServiceInfo(from: serviceInfoURL)
        default:
            print("Unsupported endpoint type: \(endpoint)")
        }
    }

    private func handleServiceLost(_ endpoint: NWEndpoint) {
        // 处理服务丢失
        print("Service lost: \(endpoint)")
    }

    private func fetchServiceInfo(from urlString: String) {
        guard let url = URL(string: urlString) else { return }

        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                print("Failed to fetch service info: \(error)")
                return
            }

            if let data = data, let info = String(data: data, encoding: .utf8) {
                print("Fetched service info: \(info)")
                // 处理从服务端获取的信息
            }
        }

        task.resume()
    }
}
