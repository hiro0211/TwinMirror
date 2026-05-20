import XCTest
@testable import TwinMirror

final class ChildAgePromptsTests: XCTestCase {

    func test_block_isNonEmptyForEveryYearInRange() {
        for y in ChildAge.allYears {
            let block = ChildAgePrompts.block(for: ChildAge(years: y))
            XCTAssertFalse(block.isEmpty, "block for age \(y) must be non-empty")
        }
    }

    func test_block_containsExactYearNumber() {
        for y in ChildAge.allYears {
            let block = ChildAgePrompts.block(for: ChildAge(years: y))
            XCTAssertTrue(
                block.contains("\(y)"),
                "block for age \(y) must include the literal year number; got: \(block)"
            )
        }
    }

    func test_block_newbornMentionsInfantTerm() {
        let block = ChildAgePrompts.block(for: ChildAge(years: 0)).lowercased()
        XCTAssertTrue(
            block.contains("newborn") || block.contains("infant"),
            "0-year-old block should mention newborn/infant; got: \(block)"
        )
    }

    func test_block_toddlerMentionsToddlerTerm() {
        let block = ChildAgePrompts.block(for: ChildAge(years: 3)).lowercased()
        XCTAssertTrue(block.contains("toddler"))
    }

    func test_block_childMentionsKindergartenOrElementary() {
        let block = ChildAgePrompts.block(for: ChildAge(years: 6)).lowercased()
        XCTAssertTrue(
            block.contains("kindergarten") || block.contains("elementary") || block.contains("young child")
        )
    }

    func test_block_preteenMentionsPreTeenOrUpperElementary() {
        let block = ChildAgePrompts.block(for: ChildAge(years: 11)).lowercased()
        XCTAssertTrue(
            block.contains("pre-teen") || block.contains("preteen") || block.contains("upper elementary")
        )
    }

    func test_block_teenMentionsTeenager() {
        let block = ChildAgePrompts.block(for: ChildAge(years: 15)).lowercased()
        XCTAssertTrue(block.contains("teen"))
    }

    func test_block_youngAdultMentionsAdult() {
        let block = ChildAgePrompts.block(for: ChildAge(years: 20)).lowercased()
        XCTAssertTrue(block.contains("adult"))
    }

    func test_block_doesNotLeaveYearsPlaceholder() {
        for y in ChildAge.allYears {
            let block = ChildAgePrompts.block(for: ChildAge(years: y))
            XCTAssertFalse(block.contains("{years}"), "unfilled {years} for age \(y): \(block)")
            XCTAssertFalse(block.contains("{{"), "unfilled placeholder for age \(y): \(block)")
        }
    }
}
