public enum AwakeState: Equatable, Sendable {
    case normal
    case awake
    case error(String)

    public var isFullyAwake: Bool {
        if case .awake = self {
            return true
        }
        return false
    }

    public var shortStatus: String {
        switch self {
        case .normal:
            "Normal"
        case .awake:
            "Awake"
        case .error:
            "Error"
        }
    }
}
