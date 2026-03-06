import XCTest
@testable import NvidiaBar

final class SSHConfigDiscoveryTests: XCTestCase {
    func testParseImportsConcreteHostBlocksOnly() {
        let contents = """
        Host *.example
            User ignored

        Host gpu-server-1 gpu-server-2
            HostName 192.0.2.10
            User gpu-user
            Port 22
            IdentityFile /path/to/private/key
        """

        let configs = SSHConfigDiscovery().parse(contents)

        XCTAssertEqual(configs.count, 2)
        XCTAssertEqual(configs.map(\.hostAlias), ["gpu-server-1", "gpu-server-2"])
        XCTAssertEqual(configs.first?.connectionMode, .sshAlias)
        XCTAssertEqual(configs.first?.hostName, "192.0.2.10")
        XCTAssertEqual(configs.first?.userName, "gpu-user")
        XCTAssertEqual(configs.first?.port, 22)
    }
}
