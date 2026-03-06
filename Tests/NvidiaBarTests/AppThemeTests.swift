import XCTest
@testable import NvidiaBar

final class AppThemeTests: XCTestCase {
    func testThemeRawValuesStayStable() {
        XCTAssertEqual(AppTheme.allCases.map(\.rawValue), ["light", "dark"])
    }

    func testInvalidRawValueFallsBackToDefaultTheme() {
        XCTAssertEqual(AppTheme(rawValue: "invalid") ?? AppTheme.defaultValue, .light)
    }
}
