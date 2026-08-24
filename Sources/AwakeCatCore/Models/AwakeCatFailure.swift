import Foundation

public struct AwakeCatFailure: LocalizedError, Equatable, Sendable {
    public let summary: String
    public let detail: String

    public init(summary: String, detail: String) {
        self.summary = summary
        self.detail = detail
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
