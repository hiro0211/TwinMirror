import XCTest
@testable import TwinMirror

final class ChildAgeTests: XCTestCase {

    func test_displayName_appendsYearsSuffix() {
        XCTAssertEqual(ChildAge(years: 0).displayName, "0歳")
        XCTAssertEqual(ChildAge(years: 5).displayName, "5歳")
        XCTAssertEqual(ChildAge(years: 20).displayName, "20歳")
    }

    func test_isMajorTick_atZeroFiveTenFifteenTwenty() {
        XCTAssertTrue(ChildAge(years: 0).isMajorTick)
        XCTAssertTrue(ChildAge(years: 5).isMajorTick)
        XCTAssertTrue(ChildAge(years: 10).isMajorTick)
        XCTAssertTrue(ChildAge(years: 15).isMajorTick)
        XCTAssertTrue(ChildAge(years: 20).isMajorTick)
    }

    func test_isMajorTick_falseForNonMultiplesOfFive() {
        for y in [1, 2, 3, 4, 6, 7, 8, 9, 11, 12, 13, 14, 16, 17, 18, 19] {
            XCTAssertFalse(ChildAge(years: y).isMajorTick, "\(y) should not be a major tick")
        }
    }

    func test_bucket_newborn_for0to1() {
        XCTAssertEqual(ChildAge(years: 0).bucket, .newborn)
        XCTAssertEqual(ChildAge(years: 1).bucket, .newborn)
    }

    func test_bucket_toddler_for2to4() {
        XCTAssertEqual(ChildAge(years: 2).bucket, .toddler)
        XCTAssertEqual(ChildAge(years: 3).bucket, .toddler)
        XCTAssertEqual(ChildAge(years: 4).bucket, .toddler)
    }

    func test_bucket_child_for5to9() {
        XCTAssertEqual(ChildAge(years: 5).bucket, .child)
        XCTAssertEqual(ChildAge(years: 9).bucket, .child)
    }

    func test_bucket_preteen_for10to12() {
        XCTAssertEqual(ChildAge(years: 10).bucket, .preteen)
        XCTAssertEqual(ChildAge(years: 12).bucket, .preteen)
    }

    func test_bucket_teen_for13to17() {
        XCTAssertEqual(ChildAge(years: 13).bucket, .teen)
        XCTAssertEqual(ChildAge(years: 17).bucket, .teen)
    }

    func test_bucket_youngAdult_for18to20() {
        XCTAssertEqual(ChildAge(years: 18).bucket, .youngAdult)
        XCTAssertEqual(ChildAge(years: 20).bucket, .youngAdult)
    }

    func test_clamped_keepsInRange() {
        XCTAssertEqual(ChildAge.clamped(years: -3).years, 0)
        XCTAssertEqual(ChildAge.clamped(years: 0).years, 0)
        XCTAssertEqual(ChildAge.clamped(years: 7).years, 7)
        XCTAssertEqual(ChildAge.clamped(years: 25).years, 20)
    }

    func test_default_isFiveYears() {
        XCTAssertEqual(ChildAge.default.years, 5)
    }

    func test_rangeConstants() {
        XCTAssertEqual(ChildAge.minYears, 0)
        XCTAssertEqual(ChildAge.maxYears, 20)
        XCTAssertEqual(ChildAge.allYears, Array(0...20))
    }
}
