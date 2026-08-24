import XCTest
@testable import AwakeCatCore

final class IdleProtectionCoordinatorTests: XCTestCase {
    func testForwardsAcquisitionAndReleaseToPowerService() throws {
        let power = FakePowerProvider()
        let coordinator = IdleProtectionCoordinator(powerAssertions: power)

        let session = try coordinator.begin()
        XCTAssertEqual(power.beginCount, 1)
        XCTAssertEqual(power.activeCount, 1)

        try session.end()
        XCTAssertEqual(power.endCount, 1)
        XCTAssertEqual(power.activeCount, 0)
    }

    func testRestoreIsNoOpBecauseAssertionsAreProcessOwned() throws {
        let power = FakePowerProvider()
        let coordinator = IdleProtectionCoordinator(powerAssertions: power)

        XCTAssertNoThrow(try coordinator.restoreStaleStateIfNeeded())
        XCTAssertEqual(power.beginCount, 0)
    }
}

private final class FakePowerProvider: PowerAssertionProviding {
    var beginCount = 0
    var endCount = 0
    var activeCount = 0

    func begin() throws -> any IdleProtectionSession {
        beginCount += 1
        activeCount += 1
        return FakeCoordinatorSession { [weak self] in
            self?.endCount += 1
            self?.activeCount -= 1
        }
    }
}

private final class FakeCoordinatorSession: IdleProtectionSession {
    private var action: (() -> Void)?

    init(action: @escaping () -> Void) {
        self.action = action
    }

    func end() throws {
        action?()
        action = nil
    }
}
