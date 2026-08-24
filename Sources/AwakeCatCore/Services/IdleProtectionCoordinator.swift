public final class IdleProtectionCoordinator: IdleProtectionProviding {
    private let powerAssertions: any PowerAssertionProviding

    public init(powerAssertions: any PowerAssertionProviding) {
        self.powerAssertions = powerAssertions
    }

    public static func live() -> IdleProtectionCoordinator {
        IdleProtectionCoordinator(
            powerAssertions: IOKitPowerAssertionService()
        )
    }

    public func restoreStaleStateIfNeeded() throws {
        // IOKit assertions are process-owned and macOS removes them when the
        // process exits, so AwakeCat has no persistent state to recover.
    }

    public func begin() throws -> any IdleProtectionSession {
        try powerAssertions.begin()
    }
}
