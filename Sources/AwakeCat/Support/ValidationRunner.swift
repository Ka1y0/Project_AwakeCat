import AwakeCatCore
import Darwin
import Foundation

#if DEBUG
enum ValidationRunner {
    static func runIfRequested(arguments: [String]) -> Int32? {
        guard arguments.count >= 2 else {
            return nil
        }

        let command = arguments[1]
        do {
            switch command {
            case "--validation-awake-seconds":
                let seconds = try duration(from: arguments)
                try runFullProtection(seconds: seconds)
                return 0
            case "--validation-power-only-seconds":
                let seconds = try duration(from: arguments)
                try runPowerOnly(seconds: seconds)
                return 0
            case "--validation-cycle":
                let count = try count(from: arguments)
                try runCycles(count: count)
                return 0
            case "--validation-crash-after-awake":
                let coordinator = IdleProtectionCoordinator.live()
                try coordinator.restoreStaleStateIfNeeded()
                let session = try coordinator.begin()
                withExtendedLifetime(session) {
                    writeLine("AWAKE_READY pid=\(getpid()) crash-test=1 stopped=1")
                    // Freeze with both assertions live so the harness can
                    // inspect pmset and then deliver SIGKILL.
                    _ = raise(SIGSTOP)
                    _exit(99)
                }
                return 99
            case "--validation-restore-only":
                try IdleProtectionCoordinator.live().restoreStaleStateIfNeeded()
                writeLine("RESTORE_COMPLETE pid=\(getpid())")
                return 0
            default:
                return nil
            }
        } catch {
            writeLine("VALIDATION_ERROR \(error.localizedDescription)", to: .standardError)
            return 1
        }
    }

    private static func runFullProtection(seconds: TimeInterval) throws {
        let coordinator = IdleProtectionCoordinator.live()
        try coordinator.restoreStaleStateIfNeeded()
        let session = try coordinator.begin()
        writeLine("AWAKE_READY pid=\(getpid()) mode=full")
        Thread.sleep(forTimeInterval: seconds)
        try session.end()
        writeLine("NORMAL_READY pid=\(getpid())")
    }

    private static func runPowerOnly(seconds: TimeInterval) throws {
        let session = try IOKitPowerAssertionService().begin()
        writeLine("AWAKE_READY pid=\(getpid()) mode=power-only")
        Thread.sleep(forTimeInterval: seconds)
        try session.end()
        writeLine("NORMAL_READY pid=\(getpid())")
    }

    private static func runCycles(count: Int) throws {
        let coordinator = IdleProtectionCoordinator.live()
        try coordinator.restoreStaleStateIfNeeded()

        for cycle in 1...count {
            let session = try coordinator.begin()
            writeLine("CYCLE_ON index=\(cycle) pid=\(getpid())")
            Thread.sleep(forTimeInterval: 0.05)
            try session.end()
            writeLine("CYCLE_OFF index=\(cycle) pid=\(getpid())")
        }
    }

    private static func duration(from arguments: [String]) throws -> TimeInterval {
        guard arguments.count == 3,
              let seconds = TimeInterval(arguments[2]),
              seconds > 0,
              seconds <= 1_800 else {
            throw ValidationArgumentError.invalidDuration
        }
        return seconds
    }

    private static func count(from arguments: [String]) throws -> Int {
        guard arguments.count == 3,
              let count = Int(arguments[2]),
              (1...100).contains(count) else {
            throw ValidationArgumentError.invalidCount
        }
        return count
    }

    private static func writeLine(_ text: String, to handle: FileHandle = .standardOutput) {
        handle.write(Data("\(text)\n".utf8))
    }
}

private enum ValidationArgumentError: LocalizedError {
    case invalidDuration
    case invalidCount

    var errorDescription: String? {
        switch self {
        case .invalidDuration:
            "Validation duration must be between 1 and 1800 seconds."
        case .invalidCount:
            "Validation cycle count must be between 1 and 100."
        }
    }
}
#endif
