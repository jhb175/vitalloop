import Foundation

enum HealthPermissionState: Equatable, Sendable {
    case notRequested
    case unavailable
    case requesting
    case authorized
    case partialData(Int, Int)
    case noData
    case readFailed(String)
    case denied(String)

    var displayTitle: String {
        switch self {
        case .notRequested:
            return "等待健康权限"
        case .unavailable:
            return "此设备不支持 HealthKit"
        case .requesting:
            return "正在请求健康权限"
        case .authorized:
            return "已连接 Apple 健康"
        case .partialData:
            return "Apple 健康数据不完整"
        case .noData:
            return "未读到今日健康数据"
        case .readFailed:
            return "Apple 健康读取失败"
        case .denied:
            return "未连接 Apple 健康"
        }
    }
}
