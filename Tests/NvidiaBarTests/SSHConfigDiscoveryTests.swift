import XCTest
@testable import NvidiaBar

final class SSHConfigDiscoveryTests: XCTestCase {
    func testParseImportsConcreteHostBlocksOnly() {
        let contents = """
        Host *.example
            User ignored

        Host shiyanshi1 shiyanshi2
            HostName 172.18.1.243
            User ct
            Port 22
            IdentityFile ~/.ssh/id_rsa
        """

        let configs = SSHConfigDiscovery().parse(contents)

        XCTAssertEqual(configs.count, 2)
        XCTAssertEqual(configs.map(\.hostAlias), ["shiyanshi1", "shiyanshi2"])
        XCTAssertEqual(configs.first?.connectionMode, .sshAlias)
        XCTAssertEqual(configs.first?.hostName, "172.18.1.243")
        XCTAssertEqual(configs.first?.userName, "ct")
        XCTAssertEqual(configs.first?.port, 22)
    }
}
