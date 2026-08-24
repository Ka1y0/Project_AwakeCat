import AppKit
import AwakeCatCore
import Darwin

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private let stateController = AwakeStateController(
        protectionProvider: IdleProtectionCoordinator.live()
    )
    private let launchAtLoginController = LaunchAtLoginController()
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        stateController.prepareForLaunch()

        let statusItemController = StatusItemController(
            stateController: stateController,
            launchAtLoginController: launchAtLoginController
        )
        self.statusItemController = statusItemController
        statusItemController.presentCurrentErrorIfNeeded()

        #if DEBUG
        if CommandLine.arguments.contains("--validation-ui-awake") {
            statusItemController.performValidationPrimaryClick()
        }
        if CommandLine.arguments.contains("--validation-ui-menu") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                statusItemController.showValidationContextMenu()
            }
        }
        #endif
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard stateController.shutdown() else {
            statusItemController?.presentCurrentErrorIfNeeded()
            return .terminateCancel
        }
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        _ = stateController.shutdown()
    }
}

@main
enum AwakeCatApp {
    @MainActor
    static func main() {
        #if DEBUG
        if let result = ValidationRunner.runIfRequested(
            arguments: CommandLine.arguments
        ) {
            exit(result)
        }
        #endif

        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }
}
