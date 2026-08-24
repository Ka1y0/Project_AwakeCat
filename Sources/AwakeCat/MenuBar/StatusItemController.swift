import AppKit
import AwakeCatCore

@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let stateController: AwakeStateController
    private let launchAtLoginController: LaunchAtLoginController

    init(
        stateController: AwakeStateController,
        launchAtLoginController: LaunchAtLoginController
    ) {
        self.stateController = stateController
        self.launchAtLoginController = launchAtLoginController
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        guard let button = statusItem.button else {
            return
        }
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.target = self
        button.action = #selector(handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.setAccessibilityCustomActions([
            NSAccessibilityCustomAction(
                name: "Show AwakeCat Menu",
                target: self,
                selector: #selector(showAccessibilityMenu(_:))
            )
        ])

        stateController.onStateChange = { [weak self] state in
            self?.render(state)
        }
        render(stateController.state)
    }

    func presentCurrentErrorIfNeeded() {
        guard case let .error(message) = stateController.state else {
            return
        }
        presentError(title: "AwakeCat needs attention", message: message)
    }

    #if DEBUG
    func performValidationPrimaryClick() {
        statusItem.button?.performClick(nil)
    }

    func showValidationContextMenu() {
        showContextMenu()
    }
    #endif

    @objc private func handleStatusItemClick(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            toggleAwake()
            return
        }

        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showContextMenu()
        } else {
            toggleAwake()
        }
    }

    @objc private func toggleAwake() {
        let succeeded = stateController.toggle()
        if !succeeded, case let .error(message) = stateController.state {
            presentError(
                title: "Awake mode was not enabled",
                message: message
            )
        }
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            try launchAtLoginController.toggle()
        } catch {
            presentError(
                title: "Launch at Login could not be changed",
                message: error.localizedDescription
            )
        }
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "AwakeCat",
            .applicationVersion: "0.1.0",
            .credits: NSAttributedString(
                string: "A tiny, fully local idle-sleep and automatic-lock prevention utility."
            )
        ])
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func showAccessibilityMenu(
        _ action: NSAccessibilityCustomAction
    ) -> Bool {
        showContextMenu()
        return true
    }

    private func render(_ state: AwakeState) {
        guard let button = statusItem.button else {
            return
        }
        button.image = CatStatusIcon.image(for: state)
        button.toolTip = tooltip(for: state)
        button.setAccessibilityLabel("AwakeCat")
        button.setAccessibilityValue(accessibilityValue(for: state))
        button.setAccessibilityHelp(tooltip(for: state))
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let status = NSMenuItem(
            title: "Status: \(stateController.state.shortStatus)",
            action: nil,
            keyEquivalent: ""
        )
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        let keepAwake = NSMenuItem(
            title: "Keep Awake",
            action: #selector(toggleAwake),
            keyEquivalent: ""
        )
        keepAwake.target = self
        keepAwake.state = stateController.state.isFullyAwake ? .on : .off
        keepAwake.isEnabled = true
        menu.addItem(keepAwake)

        let launchAtLogin = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLogin.target = self
        launchAtLogin.isEnabled = true
        switch launchAtLoginController.displayState {
        case .off:
            launchAtLogin.state = .off
        case .on:
            launchAtLogin.state = .on
        case .requiresApproval:
            launchAtLogin.state = .mixed
        case .unavailable:
            launchAtLogin.state = .off
            launchAtLogin.isEnabled = false
        }
        menu.addItem(launchAtLogin)
        menu.addItem(.separator())

        let about = NSMenuItem(
            title: "About AwakeCat",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        about.target = self
        about.isEnabled = true
        menu.addItem(about)

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitItem.isEnabled = true
        menu.addItem(quitItem)

        guard let button = statusItem.button else {
            return
        }
        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil
    }

    private func tooltip(for state: AwakeState) -> String {
        switch state {
        case .normal:
            "AwakeCat: Normal"
        case .awake:
            "AwakeCat: Awake — idle sleep and automatic lock prevention active"
        case .error:
            "AwakeCat: Error — click to retry or right-click for controls"
        }
    }

    private func accessibilityValue(for state: AwakeState) -> String {
        switch state {
        case .normal:
            "Normal"
        case .awake:
            "Awake. Idle sleep and automatic lock prevention active."
        case let .error(message):
            "Error. \(message)"
        }
    }

    private func presentError(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
