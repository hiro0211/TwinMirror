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

    // MARK: - Blend ratio substitution

    func test_build_balancedBlend_substitutesBlendBlock() throws {
        let prompt = try makeBuilder().build(
            style: .photorealistic, gender: .female, age: .default, blendRatio: .balanced
        )
        XCTAssertFalse(prompt.contains("{{BLEND_BLOCK}}"))
        XCTAssertTrue(prompt.contains("BALANCED"), "balanced template should include BALANCED keyword")
    }

    func test_build_fatherLeaning_emphasizesFather() throws {
        let prompt = try makeBuilder().build(
            style: .photorealistic, gender: .female, age: .default, blendRatio: .fatherLeaning
        )
        XCTAssertFalse(prompt.contains("{{BLEND_BLOCK}}"))
        XCTAssertTrue(prompt.contains("FATHER-LEANING"))
        XCTAssertTrue(prompt.contains("Image A (FATHER)"))
        XCTAssertTrue(prompt.contains("70%"))
    }

    func test_build_motherLeaning_emphasizesMother() throws {
        let prompt = try makeBuilder().build(
            style: .photorealistic, gender: .female, age: .default, blendRatio: .motherLeaning
        )
        XCTAssertFalse(prompt.contains("{{BLEND_BLOCK}}"))
        XCTAssertTrue(prompt.contains("MOTHER-LEANING"))
        XCTAssertTrue(prompt.contains("Image B (MOTHER)"))
        XCTAssertTrue(prompt.contains("70%"))
    }

    func test_build_threeRatios_produceDifferentPrompts() throws {
        let builder = makeBuilder()
        let balanced = try builder.build(style: .photorealistic, gender: .female, age: .default, blendRatio: .balanced)
        let father   = try builder.build(style: .photorealistic, gender: .female, age: .default, blendRatio: .fatherLeaning)
        let mother   = try builder.build(style: .photorealistic, gender: .female, age: .default, blendRatio: .motherLeaning)
        XCTAssertNotEqual(balanced, father)
        XCTAssertNotEqual(balanced, mother)
        XCTAssertNotEqual(father, mother)
    }

    func test_build_illustration_alsoSubstitutesBlendBlock() throws {
        let prompt = try makeBuilder().build(
            style: .illustration, gender: .female, age: .default, blendRatio: .fatherLeaning
        )
        XCTAssertFalse(prompt.contains("{{BLEND_BLOCK}}"))
        XCTAssertTrue(prompt.contains("FATHER-LEANING"))
    }

    private func makeBuilder() -> PromptBuilder {
        PromptBuilder(bundle: .main)
    }
}
