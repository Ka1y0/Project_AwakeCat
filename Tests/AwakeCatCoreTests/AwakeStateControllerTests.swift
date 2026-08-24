import XCTest
@testable import AwakeCatCore

@MainActor
final class AwakeStateControllerTests: XCTestCase {
    func testStartsNormalAndBecomesAwakeOnlyAfterSuccessfulAcquisition() {
        let provider = FakeProtectionProvider()
        let controller = AwakeStateController(protectionProvider: provider)

        XCTAssertEqual(controller.state, .normal)
        XCTAssertTrue(controller.enable())
        XCTAssertEqual(controller.state, .awake)
        XCTAssertEqual(provider.beginCount, 1)
        XCTAssertEqual(provider.activeSessionCount, 1)
    }

    func testAcquisitionFailureNeverShowsAwake() {
        let provider = FakeProtectionProvider()
        provider.beginError = AwakeCatFailure(summary: "No protection", detail: "test")
        let controller = AwakeStateController(protectionProvider: provider)

        XCTAssertFalse(controller.enable())
        XCTAssertEqual(controller.state, .error("No protection: test"))
        XCTAssertEqual(provider.activeSessionCount, 0)
    }

    func testIncompleteAcquisitionRollbackRetainsCleanupSessionForRetry() {
        let provider = FakeProtectionProvider()
        provider.activeSessionCount = 1
        provider.beginError = IdleProtectionAcquisitionFailure(
            summary: "Partial protection remains",
            detail: "cleanup must be retried",
            cleanupSession: FakeSession(owner: provider)
        )
        let controller = AwakeStateController(protectionProvider: provider)

        XCTAssertFalse(controller.enable())
        XCTAssertEqual(
            controller.state,
            .error("Partial protection remains: cleanup must be retried")
        )
        XCTAssertEqual(provider.activeSessionCount, 1)

        XCTAssertTrue(controller.toggle())
        XCTAssertEqual(controller.state, .normal)
        XCTAssertEqual(provider.activeSessionCount, 0)
    }

    func testDisableFailureRetainsSessionForRetry() {
        let provider = FakeProtectionProvider()
        provider.endFailuresRemaining = 1
        let controller = AwakeStateController(protectionProvider: provider)

        XCTAssertTrue(controller.enable())
        XCTAssertFalse(controller.disable())
        XCTAssertEqual(
            controller.state,
            .error("Test cleanup failed: retry is required")
        )
        XCTAssertEqual(provider.activeSessionCount, 1)

        XCTAssertTrue(controller.disable())
        XCTAssertEqual(controller.state, .normal)
        XCTAssertEqual(provider.activeSessionCount, 0)
    }

    func testTenOnOffCyclesLeaveNoActiveSession() {
        let provider = FakeProtectionProvider()
        let controller = AwakeStateController(protectionProvider: provider)

        for _ in 0..<10 {
            XCTAssertTrue(controller.enable())
            XCTAssertEqual(controller.state, .awake)
            XCTAssertTrue(controller.disable())
            XCTAssertEqual(controller.state, .normal)
        }

        XCTAssertEqual(provider.beginCount, 10)
        XCTAssertEqual(provider.endCount, 10)
        XCTAssertEqual(provider.activeSessionCount, 0)
    }

    func testPrepareForLaunchSurfacesRecoveryFailure() {
        let provider = FakeProtectionProvider()
        provider.restoreError = AwakeCatFailure(
            summary: "Recovery failed",
            detail: "metadata retained"
        )
        let controller = AwakeStateController(protectionProvider: provider)

        controller.prepareForLaunch()

        XCTAssertEqual(
            controller.state,
            .error("Recovery failed: metadata retained")
        )
    }
}

private final class FakeProtectionProvider: IdleProtectionProviding {
    var beginCount = 0
    var endCount = 0
    var activeSessionCount = 0
    var endFailuresRemaining = 0
    var beginError: Error?
    var restoreError: Error?

    func restoreStaleStateIfNeeded() throws {
        if let restoreError {
            throw restoreError
        }
    }

    func begin() throws -> any IdleProtectionSession {
        if let beginError {
            throw beginError
        }
        beginCount += 1
        activeSessionCount += 1
        return FakeSession(owner: self)
    }

    fileprivate func endSession() throws {
        if endFailuresRemaining > 0 {
            endFailuresRemaining -= 1
            throw AwakeCatFailure(
                summary: "Test cleanup failed",
                detail: "retry is required"
            )
        }
        endCount += 1
        activeSessionCount -= 1
    }
}

private final class FakeSession: IdleProtectionSession {
    private let owner: FakeProtectionProvider
    private var active = true

    init(owner: FakeProtectionProvider) {
        self.owner = owner
    }

    func end() throws {
        guard active else {
            return
        }
        try owner.endSession()
        active = false
    }
}
