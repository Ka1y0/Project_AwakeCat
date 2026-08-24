import Foundation
import IOKit.pwr_mgt

public final class IOKitPowerAssertionService: PowerAssertionProviding {
    public static let systemAssertionName = "AwakeCat: prevent automatic idle system sleep"
    public static let displayAssertionName = "AwakeCat: keep display awake to prevent automatic idle lock"

    public init() {}

    public func begin() throws -> any IdleProtectionSession {
        var acquiredIDs: [IOPMAssertionID] = []

        do {
            acquiredIDs.append(
                try createAssertion(
                    type: kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                    name: Self.systemAssertionName
                )
            )
            acquiredIDs.append(
                try createAssertion(
                    type: kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                    name: Self.displayAssertionName
                )
            )
            return IOKitPowerAssertionSession(assertionIDs: acquiredIDs)
        } catch {
            var unreleasedIDs: [IOPMAssertionID] = []
            var rollbackFailures: [String] = []
            for assertionID in acquiredIDs.reversed() {
                let result = IOPMAssertionRelease(assertionID)
                if result != kIOReturnSuccess {
                    unreleasedIDs.append(assertionID)
                    rollbackFailures.append(
                        "assertion \(assertionID) returned \(Self.hex(result))"
                    )
                }
            }

            if !rollbackFailures.isEmpty {
                let cleanupSession = IOKitPowerAssertionSession(
                    assertionIDs: unreleasedIDs.reversed()
                )
                throw IdleProtectionAcquisitionFailure(
                    summary: "Power protection was not fully acquired",
                    detail: "\(Self.message(for: error)) Rollback also failed: \(rollbackFailures.joined(separator: "; ")).",
                    cleanupSession: cleanupSession
                )
            }
            throw error
        }
    }

    private func createAssertion(type: CFString, name: String) throws -> IOPMAssertionID {
        var assertionID = IOPMAssertionID(kIOPMNullAssertionID)
        let result = IOPMAssertionCreateWithName(
            type,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            name as CFString,
            &assertionID
        )

        guard result == kIOReturnSuccess else {
            throw AwakeCatFailure(
                summary: "Power protection could not be acquired",
                detail: "IOKit returned \(Self.hex(result)) for \(type)."
            )
        }
        return assertionID
    }

    private static func hex(_ value: IOReturn) -> String {
        String(format: "0x%08x", UInt32(bitPattern: value))
    }

    private static func message(for error: Error) -> String {
        if let failure = error as? AwakeCatFailure {
            return failure.displayText
        }
        return error.localizedDescription
    }
}

private final class IOKitPowerAssertionSession: IdleProtectionSession {
    private var assertionIDs: [IOPMAssertionID]

    init(assertionIDs: [IOPMAssertionID]) {
        self.assertionIDs = assertionIDs
    }

    func end() throws {
        var unreleased: [IOPMAssertionID] = []
        var failures: [String] = []

        for assertionID in assertionIDs.reversed() {
            let result = IOPMAssertionRelease(assertionID)
            if result != kIOReturnSuccess {
                unreleased.append(assertionID)
                failures.append(
                    "assertion \(assertionID) returned \(String(format: "0x%08x", UInt32(bitPattern: result)))"
                )
            }
        }

        assertionIDs = unreleased.reversed()
        guard failures.isEmpty else {
            throw AwakeCatFailure(
                summary: "Power protection could not be fully released",
                detail: failures.joined(separator: "; ")
            )
        }
    }

    deinit {
        for assertionID in assertionIDs {
            _ = IOPMAssertionRelease(assertionID)
        }
    }
}
