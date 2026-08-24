import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginController {
    enum DisplayState {
        case off
        case on
        case requiresApproval
        case unavailable
    }

    var displayState: DisplayState {
        switch SMAppService.mainApp.status {
        case .notRegistered:
            .off
        case .enabled:
            .on
        case .requiresApproval:
            .requiresApproval
        case .notFound:
            .unavailable
        @unknown default:
            .unavailable
        }
    }

    func toggle() throws {
        switch SMAppService.mainApp.status {
        case .enabled:
            try SMAppService.mainApp.unregister()
        case .notRegistered, .requiresApproval:
            try SMAppService.mainApp.register()
        case .notFound:
            throw LaunchAtLoginError.appNotInstalled
        @unknown default:
            throw LaunchAtLoginError.unknownStatus
        }
    }
}
private enum LaunchAtLoginError: LocalizedError {
    case appNotInstalled
    case unknownStatus

    var errorDescription: String? {
        switch self {
        case .appNotInstalled:
            "Launch at Login is unavailable until AwakeCat is installed in Applications."
        case .unknownStatus:
            "Launch at Login returned an unknown macOS status."
        }
    }
}
