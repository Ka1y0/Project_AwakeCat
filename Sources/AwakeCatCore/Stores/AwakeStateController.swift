@MainActor
public final class AwakeStateController {
    public private(set) var state: AwakeState = .normal {
        didSet {
            onStateChange?(state)
        }
    }

    public var onStateChange: ((AwakeState) -> Void)?

    private let protectionProvider: any IdleProtectionProviding
    private var activeSession: (any IdleProtectionSession)?

    public init(protectionProvider: any IdleProtectionProviding) {
        self.protectionProvider = protectionProvider
    }

    public func prepareForLaunch() {
        do {
            try protectionProvider.restoreStaleStateIfNeeded()
            state = .normal
        } catch {
            state = .error(Self.message(for: error))
        }
    }

    @discardableResult
    public func toggle() -> Bool {
        activeSession == nil ? enable() : disable()
    }

    @discardableResult
    public func enable() -> Bool {
        guard activeSession == nil else {
            state = .awake
            return true
        }

        do {
            try protectionProvider.restoreStaleStateIfNeeded()
            let session = try protectionProvider.begin()
            activeSession = session
            state = .awake
            return true
        } catch let failure as IdleProtectionAcquisitionFailure {
            activeSession = failure.cleanupSession
            state = .error(failure.displayText)
            return false
        } catch {
            state = .error(Self.message(for: error))
            return false
        }
    }

    @discardableResult
    public func disable() -> Bool {
        guard let activeSession else {
            state = .normal
            return true
        }

        do {
            try activeSession.end()
            self.activeSession = nil
            state = .normal
            return true
        } catch {
            state = .error(Self.message(for: error))
            return false
        }
    }

    @discardableResult
    public func shutdown() -> Bool {
        disable()
    }

    private static func message(for error: Error) -> String {
        if let failure = error as? AwakeCatFailure {
            return failure.displayText
        }
        return error.localizedDescription
    }
}
