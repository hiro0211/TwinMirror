import XCTest
@testable import TwinMirror

final class BlendRatioTests: XCTestCase {

    func test_balanced_is50_50() {
        XCTAssertEqual(BlendRatio.balanced.fatherPercent, 50)
        XCTAssertEqual(BlendRatio.balanced.motherPercent, 50)
    }

    func test_fatherLeaning_is70_30() {
        XCTAssertEqual(BlendRatio.fatherLeaning.fatherPercent, 70)
        XCTAssertEqual(BlendRatio.fatherLeaning.motherPercent, 30)
    }

    func test_motherLeaning_is30_70() {
        XCTAssertEqual(BlendRatio.motherLeaning.fatherPercent, 30)
        XCTAssertEqual(BlendRatio.motherLeaning.motherPercent, 70)
    }

    func test_percentagesAlwaysSumTo100() {
        for r in BlendRatio.allCases {
            XCTAssertEqual(r.fatherPercent + r.motherPercent, 100, "Ratio \(r) must sum to 100")
        }
    }

    func test_displayLabel_isJapanese() {
        XCTAssertEqual(BlendRatio.balanced.displayLabel,       "両親半々")
        XCTAssertEqual(BlendRatio.fatherLeaning.displayLabel,  "お父さん似")
        XCTAssertEqual(BlendRatio.motherLeaning.displayLabel,  "お母さん似")
    }

    func test_generationMode_fast_yields1Ratio() {
        XCTAssertEqual(GenerationMode.fast.blendRatios, [.balanced])
    }

    func test_generationMode_premium_yields3Ratios() {
        XCTAssertEqual(GenerationMode.premium.blendRatios,
                       [.balanced, .fatherLeaning, .motherLeaning])
    }

    func test_generationMode_premium_imageCountIs3() {
        XCTAssertEqual(GenerationMode.premium.blendRatios.count, 3)
    }

    func test_generationMode_fast_imageCountIs1() {
        XCTAssertEqual(GenerationMode.fast.blendRatios.count, 1)
    }
}
