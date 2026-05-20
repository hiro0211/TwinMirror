import XCTest
@testable import TwinMirror

final class PromptBuilderTests: XCTestCase {

    func test_build_realistic_female_containsGenderToken() throws {
        let prompt = try makeBuilder().build(style: .photorealistic, gender: .female, age: .default)
        XCTAssertTrue(prompt.contains("GENDER: female"))
        XCTAssertFalse(prompt.contains("{{GENDER}}"))
    }

    func test_build_realistic_male_containsGenderToken() throws {
        let prompt = try makeBuilder().build(style: .photorealistic, gender: .male, age: .default)
        XCTAssertTrue(prompt.contains("GENDER: male"))
    }

    func test_build_realistic_unspecified_substitutes() throws {
        let prompt = try makeBuilder().build(style: .photorealistic, gender: .unspecified, age: .default)
        XCTAssertTrue(prompt.contains("let the model decide"))
        XCTAssertFalse(prompt.contains("{{GENDER}}"))
    }

    func test_build_illustration_isClearlyStylized() throws {
        let prompt = try makeBuilder().build(style: .illustration, gender: .female, age: .default)
        let lower = prompt.lowercased()
        XCTAssertTrue(lower.contains("watercolor") || lower.contains("illustration"))
    }

    func test_build_replacesAgeBlock_andNoPlaceholderLeft() throws {
        for y in ChildAge.allYears {
            let prompt = try makeBuilder().build(
                style: .photorealistic,
                gender: .female,
                age: ChildAge(years: y)
            )
            XCTAssertFalse(prompt.contains("{{AGE_BLOCK}}"), "unfilled AGE_BLOCK at age \(y)")
            XCTAssertFalse(prompt.contains("{{GENDER}}"), "unfilled GENDER at age \(y)")
            XCTAssertTrue(prompt.contains("\(y)"), "age \(y) digit must appear in prompt")
        }
    }

    func test_build_newborn_mentionsInfantTerm() throws {
        let prompt = try makeBuilder()
            .build(style: .photorealistic, gender: .unspecified, age: ChildAge(years: 0))
            .lowercased()
        XCTAssertTrue(prompt.contains("newborn") || prompt.contains("infant"))
    }

    func test_build_twentyYears_mentionsAdult() throws {
        let prompt = try makeBuilder()
            .build(style: .photorealistic, gender: .unspecified, age: ChildAge(years: 20))
            .lowercased()
        XCTAssertTrue(prompt.contains("adult"))
    }

    func test_build_illustration_allAges_haveAgeBlock() throws {
        for y in [0, 3, 7, 11, 15, 20] {
            let prompt = try makeBuilder().build(
                style: .illustration,
                gender: .male,
                age: ChildAge(years: y)
            )
            XCTAssertFalse(prompt.contains("{{AGE_BLOCK}}"))
            XCTAssertTrue(prompt.contains("\(y)"))
        }
    }

    private func makeBuilder() -> PromptBuilder {
        PromptBuilder(bundle: .main)
    }
}
