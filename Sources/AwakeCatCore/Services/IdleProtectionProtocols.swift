import Foundation

public protocol IdleProtectionSession: AnyObject {
    func end() throws
}

public protocol IdleProtectionProviding {
    func restoreStaleStateIfNeeded() throws
    func begin() throws -> any IdleProtectionSession
}

public protocol PowerAssertionProviding {
    func begin() throws -> any IdleProtectionSession
}

/// Reports a failed acquisition whose partial rollback also failed. The
/// controller retains `cleanupSession`, renders an error state, and routes the
/// next toggle or Quit through another cleanup attempt.
public final class IdleProtectionAcquisitionFailure: LocalizedError, @unchecked Sendable {
    public let summary: String
    public let detail: String
    public let cleanupSession: any IdleProtectionSession

    public init(
        summary: String,
        detail: String,
        cleanupSession: any IdleProtectionSession
    ) {
        self.summary = summary
        self.detail = detail
        self.cleanupSession = cleanupSession
    }

    public var errorDescription: String? {
        summary
    }

    public var failureReason: String? {
        detail
    }

    public var displayText: String {
        detail.isEmpty ? summary : "\(summary): \(detail)"
    }
}
