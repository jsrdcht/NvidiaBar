import XCTest
@testable import NvidiaBar

final class ServerConfigTests: XCTestCase {
    func testLegacyConfigDecodingFallsBackToAliasMode() throws {
        let legacyJSON = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "name": "Legacy",
          "hostAlias": "gpu-alias",
          "isEnabled": true,
          "pollIntervalMinutes": 30
        }
        """

        let config = try JSONDecoder().decode(ServerConfig.self, from: Data(legacyJSON.utf8))

        XCTAssertEqual(config.connectionMode, .sshAlias)
        XCTAssertEqual(config.hostAlias, "gpu-alias")
        XCTAssertEqual(config.hostName, "")
        XCTAssertEqual(config.userName, "")
        XCTAssertEqual(config.port, 22)
    }
}
