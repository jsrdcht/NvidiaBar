import XCTest
@testable import NvidiaBar

final class PortForwardTests: XCTestCase {
    func testConfigWithoutPortForwardsDecodesToEmpty() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000010",
          "name": "Legacy",
          "hostAlias": "gpu-alias",
          "isEnabled": true,
          "pollIntervalMinutes": 30
        }
        """

        let config = try JSONDecoder().decode(ServerConfig.self, from: Data(json.utf8))
        XCTAssertEqual(config.portForwards, [])
    }

    func testPortForwardRoundTripEncoding() throws {
        let original = ServerConfig(
            name: "Server",
            connectionMode: .sshAlias,
            hostAlias: "gpu-server-1",
            isEnabled: true,
            pollIntervalMinutes: 30,
            portForwards: [
                PortForward(name: "Jupyter", remoteHost: "127.0.0.1", remotePort: 8888, localPort: 0),
                PortForward(name: "TensorBoard", remoteHost: "127.0.0.1", remotePort: 6006, localPort: 16006)
            ]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ServerConfig.self, from: data)

        XCTAssertEqual(decoded.portForwards.count, 2)
        XCTAssertEqual(decoded.portForwards[0].remotePort, 8888)
        XCTAssertTrue(decoded.portForwards[0].usesRandomLocalPort)
        XCTAssertEqual(decoded.portForwards[1].fixedLocalPort, 16006)
    }

    func testPortForwardNormalization() {
        let random = PortForward(remotePort: 70000, localPort: 0)
        XCTAssertEqual(random.normalizedRemotePort, 65_535)
        XCTAssertTrue(random.usesRandomLocalPort)
        XCTAssertNil(random.fixedLocalPort)

        let fixed = PortForward(name: "  ", remoteHost: "  ", remotePort: 8080, localPort: 9090)
        XCTAssertEqual(fixed.trimmedRemoteHost, "127.0.0.1")
        XCTAssertEqual(fixed.fixedLocalPort, 9090)
        XCTAssertFalse(fixed.usesRandomLocalPort)
    }

    func testFindFreeTCPPortReturnsUsablePort() {
        let port = PortForwardManager.findFreeTCPPort()
        XCTAssertNotNil(port)
        if let port {
            XCTAssertGreaterThan(port, 0)
            XCTAssertLessThanOrEqual(port, 65_535)
        }
    }

    func testForwardingInvocationAliasUsesBatchSSH() throws {
        let config = ServerConfig(
            name: "Alias",
            connectionMode: .sshAlias,
            hostAlias: "gpu-server-1",
            isEnabled: true,
            pollIntervalMinutes: 30
        )

        let invocation = try SSHInvocationBuilder(timeout: 15).buildForwarding(
            for: config,
            localPort: 51234,
            remoteHost: "127.0.0.1",
            remotePort: 8888
        )

        XCTAssertEqual(invocation.executablePath, "/usr/bin/env")
        XCTAssertEqual(invocation.arguments.first, "ssh")
        XCTAssertTrue(invocation.arguments.contains("-N"))
        XCTAssertTrue(invocation.arguments.contains("-L"))
        XCTAssertTrue(invocation.arguments.contains("127.0.0.1:51234:127.0.0.1:8888"))
        XCTAssertTrue(invocation.arguments.contains("ExitOnForwardFailure=yes"))
        XCTAssertTrue(invocation.arguments.contains("BatchMode=yes"))
        XCTAssertEqual(invocation.arguments.last, "gpu-server-1")
    }

    func testForwardingInvocationDirectWithPasswordUsesExpect() throws {
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

        let invocation = try SSHInvocationBuilder(timeout: 15).buildForwarding(
            for: config,
            localPort: 40000,
            remoteHost: "127.0.0.1",
            remotePort: 6006
        )
        defer { invocation.cleanup() }

        XCTAssertEqual(invocation.executablePath, "/usr/bin/expect")
        XCTAssertEqual(invocation.arguments[1], "secret")
        XCTAssertTrue(invocation.arguments.contains("-N"))
        XCTAssertTrue(invocation.arguments.contains("127.0.0.1:40000:127.0.0.1:6006"))
        XCTAssertTrue(invocation.arguments.contains("-p"))
        XCTAssertTrue(invocation.arguments.contains("2222"))
        XCTAssertTrue(invocation.arguments.contains("gpu-user@192.0.2.10"))
    }
}
