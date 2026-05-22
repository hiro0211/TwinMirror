import XCTest
@testable import TwinMirror

/// 列挙体の `analyticsValue` は Firebase 上の値として外部分析と契約する。
/// 表記揺れは無音の事故になるため、テストで凍結する。
final class OnboardingSurveyAnswersTests: XCTestCase {

    func test_ageBracket_analyticsValues_areStable() {
        XCTAssertEqual(AgeBracket.under25.analyticsValue, "under_25")
        XCTAssertEqual(AgeBracket.age25to34.analyticsValue, "25_34")
        XCTAssertEqual(AgeBracket.age35to44.analyticsValue, "35_44")
        XCTAssertEqual(AgeBracket.age45plus.analyticsValue, "45_plus")
    }

    func test_acquisitionSource_analyticsValues_areStable() {
        XCTAssertEqual(AcquisitionSource.appStore.analyticsValue, "app_store")
        XCTAssertEqual(AcquisitionSource.social.analyticsValue, "social")
        XCTAssertEqual(AcquisitionSource.wordOfMouth.analyticsValue, "word_of_mouth")
        XCTAssertEqual(AcquisitionSource.media.analyticsValue, "media")
        XCTAssertEqual(AcquisitionSource.ad.analyticsValue, "ad")
        XCTAssertEqual(AcquisitionSource.other.analyticsValue, "other")
    }

    func test_useCase_analyticsValues_areStable() {
        XCTAssertEqual(UseCase.imagineWithPartner.analyticsValue, "imagine_with_partner")
        XCTAssertEqual(UseCase.enjoyWithPartner.analyticsValue, "enjoy_with_partner")
        XCTAssertEqual(UseCase.entertainment.analyticsValue, "entertainment")
        XCTAssertEqual(UseCase.curiosity.analyticsValue, "curiosity")
    }

    func test_allCases_haveNonEmptyDisplayLabels() {
        for c in AgeBracket.allCases { XCTAssertFalse(c.displayLabel.isEmpty) }
        for c in AcquisitionSource.allCases { XCTAssertFalse(c.displayLabel.isEmpty) }
        for c in UseCase.allCases { XCTAssertFalse(c.displayLabel.isEmpty) }
    }

    func test_analyticsValues_areUniqueWithinEachEnum() {
        XCTAssertEqual(Set(AgeBracket.allCases.map(\.analyticsValue)).count, AgeBracket.allCases.count)
        XCTAssertEqual(Set(AcquisitionSource.allCases.map(\.analyticsValue)).count, AcquisitionSource.allCases.count)
        XCTAssertEqual(Set(UseCase.allCases.map(\.analyticsValue)).count, UseCase.allCases.count)
    }
}
