import XCTest
@testable import NvidiaBar

final class NvidiaSMIParserTests: XCTestCase {
    func testParseValidOutput() throws {
        let raw = """
        0, NVIDIA RTX 3090, 12, 40, 10000, 24576, 54
        1, NVIDIA RTX 4090, 90, 80, 20000, 24576, 67
        """

        let gpus = try NvidiaSMIParser().parse(raw)

        XCTAssertEqual(gpus.count, 2)
        XCTAssertEqual(gpus[0].index, 0)
        XCTAssertEqual(gpus[0].name, "NVIDIA RTX 3090")
        XCTAssertEqual(gpus[0].gpuUtilization, 12)
        XCTAssertEqual(gpus[0].memoryUtilization, 40)
        XCTAssertEqual(gpus[1].temperatureC, 67)
    }

    func testParseEmptyOutputThrows() {
        XCTAssertThrowsError(try NvidiaSMIParser().parse("")) { error in
            XCTAssertEqual(error as? NvidiaSMIParserError, .emptyOutput)
        }
    }

    func testParseMalformedOutputThrows() {
        XCTAssertThrowsError(try NvidiaSMIParser().parse("bad,line")) { error in
            XCTAssertEqual(error as? NvidiaSMIParserError, .malformedLine("bad,line"))
        }
    }
}
