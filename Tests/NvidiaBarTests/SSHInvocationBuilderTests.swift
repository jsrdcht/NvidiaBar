import XCTest
@testable import NvidiaBar

final class SSHInvocationBuilderTests: XCTestCase {
    func testAliasModeUsesBatchSSH() throws {
        let config = ServerConfig(
            name: "Alias",
            connectionMode: .sshAlias,
            hostAlias: "gpu-server-1",
            isEnabled: true,
            pollIntervalMinutes: 30
        )

        let invocation = try SSHInvocationBuilder(timeout: 12).build(for: config, remoteCommand: "nvidia-smi")

        XCTAssertEqual(invocation.executablePath, "/usr/bin/env")
        XCTAssertEqual(invocation.arguments.prefix(5), ["ssh", "-o", "ConnectTimeout=12", "-o", "BatchMode=yes"])
        XCTAssertEqual(invocation.arguments[5], "gpu-server-1")
        XCTAssertEqual(invocation.arguments.last, "nvidia-smi")
    }

    func testDirectModeWithPasswordUsesExpect() throws {
        let config = ServerConfig(
            name: "Direct",
            connectionMode: .direct,
            hostAlias: "",
            hostName: "192.0.2.10",
            userName: "gpu-user",
            port: 2222,
            identityFile: "/path/to/private/key",
            password: "secret",
            isEnabled: true,
            pollIntervalMinutes: 30
        )

        let invocation = try SSHInvocationBuilder(timeout: 15).build(for: config, remoteCommand: "nvidia-smi")
        defer {
            invocation.cleanup()
        }

        XCTAssertEqual(invocation.executablePath, "/usr/bin/expect")
        XCTAssertTrue(invocation.arguments[0].hasPrefix(FileManager.default.temporaryDirectory.path))
        XCTAssertEqual(invocation.arguments[1], "secret")
        XCTAssertTrue(invocation.arguments.contains("-p"))
        XCTAssertTrue(invocation.arguments.contains("2222"))
        XCTAssertTrue(invocation.arguments.contains("-i"))
        XCTAssertTrue(invocation.arguments.contains("/path/to/private/key"))
        XCTAssertTrue(invocation.arguments.contains("gpu-user@192.0.2.10"))
    }
}
