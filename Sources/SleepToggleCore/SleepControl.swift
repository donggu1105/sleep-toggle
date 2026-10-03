import Foundation

// 잠자기 허용 여부는 pmset의 실제 상태를 정본으로 삼는다. 관리자 인증 취소와
// 명령 성공을 구분하고, 변경 후 재조회까지 일치해야 UI에서 성공으로 표시한다.
public enum SleepMode: Int, Sendable {
    case allowed = 0
    case blocked = 1

    public var opposite: SleepMode { self == .allowed ? .blocked : .allowed }
    public var title: String { self == .allowed ? "잠자기 허용" : "잠자기 차단" }

    public static func parse(_ output: String) throws -> SleepMode {
        let entries = output.components(separatedBy: .newlines).compactMap { line -> [Substring]? in
            let fields = line.split(whereSeparator: { $0.isWhitespace })
            return fields.first == "SleepDisabled" ? fields : nil
        }
        guard entries.count == 1, entries[0].count == 2 else {
            throw SleepControlError.invalidState
        }
        switch entries[0][1] {
        case "0": return .allowed
        case "1": return .blocked
        default: throw SleepControlError.invalidState
        }
    }
}

public struct Command: Sendable, Equatable {
    public let executable: String
    public let arguments: [String]

    public init(executable: String, arguments: [String]) {
        self.executable = executable
        self.arguments = arguments
    }
}

public struct CommandResult: Sendable {
    public let status: Int32
    public let output: String

    public init(status: Int32, output: String) {
        self.status = status
        self.output = output
    }
}

public protocol CommandRunning: Sendable {
    func run(_ command: Command) async throws -> CommandResult
}

public struct ProcessRunner: CommandRunning {
    public init() {}

    public func run(_ command: Command) async throws -> CommandResult {
        // 별도 작업에서 실행하고 두 출력 스트림을 같은 파이프로 즉시 비운다.
        // 종료부터 기다리거나 두 파이프를 순서대로 읽으면 버퍼가 차서 교착될 수 있다.
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            let output = Pipe()
            process.executableURL = URL(fileURLWithPath: command.executable)
            process.arguments = command.arguments
            process.standardOutput = output
            process.standardError = output
            do {
                try process.run()
            } catch {
                throw SleepControlError.launchFailed
            }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return CommandResult(status: process.terminationStatus, output: String(decoding: data, as: UTF8.self))
        }.value
    }
}

public struct SleepController: Sendable {
    private let runner: any CommandRunning
    private static let cancellationMarker = "SLEEP_TOGGLE_CANCELLED"

    public init(runner: any CommandRunning = ProcessRunner()) {
        self.runner = runner
    }

    public func read() async throws -> SleepMode {
        let result = try await runner.run(Command(executable: "/usr/bin/pmset", arguments: ["-g"]))
        guard result.status == 0 else { throw SleepControlError.readFailed }
        return try SleepMode.parse(result.output)
    }

    public func set(_ mode: SleepMode) async throws -> SleepMode {
        // 삽입하는 값은 열거형의 0/1뿐이며 외부 문자열을 관리자 명령에 넣지 않는다.
        let script = """
        try
            do shell script "/usr/bin/pmset -a disablesleep \(mode.rawValue)" with administrator privileges
        on error errorMessage number errorNumber
            if errorNumber is -128 then
                return "\(Self.cancellationMarker)"
            end if
            error errorMessage number errorNumber
        end try
        """
        let result = try await runner.run(Command(executable: "/usr/bin/osascript", arguments: ["-e", script]))
        if result.output.trimmingCharacters(in: .whitespacesAndNewlines) == Self.cancellationMarker {
            throw SleepControlError.cancelled
        }
        guard result.status == 0 else { throw SleepControlError.changeFailed }
        let actual = try await read()
        guard actual == mode else { throw SleepControlError.verificationFailed }
        return actual
    }
}

public enum SleepControlError: Error, LocalizedError, Sendable {
    case cancelled
    case invalidState
    case launchFailed
    case readFailed
    case changeFailed
    case verificationFailed

    public var errorDescription: String? {
        switch self {
        case .cancelled: return "관리자 인증을 취소했습니다. 잠자기 설정은 변경하지 않았습니다."
        case .invalidState: return "현재 잠자기 설정을 확인할 수 없습니다. 다시 조회해 주세요."
        case .launchFailed: return "시스템 명령을 실행할 수 없습니다."
        case .readFailed: return "잠자기 설정 조회에 실패했습니다."
        case .changeFailed: return "잠자기 설정을 변경하지 못했습니다. 관리자 권한을 확인해 주세요."
        case .verificationFailed: return "변경 후 잠자기 설정이 요청한 값과 다릅니다. 다시 조회해 주세요."
        }
    }
}
