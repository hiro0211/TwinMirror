import XCTest
@testable import TwinMirror

final class OpenAIImageGeneratorTests: XCTestCase {

    func test_multipartBody_containsGptImage2Model() {
        let body = OpenAIImageGenerator.multipartBody(
            boundary: "B",
            prompt: "p",
            images: [Data([0x01]), Data([0x02])],
            n: 1
        )
        let str = String(data: body, encoding: .utf8) ?? ""
        XCTAssertTrue(str.contains("name=\"model\""), "must set model field")
        XCTAssertTrue(str.contains("gpt-image-2"), "must target gpt-image-2")
    }

    func test_multipartBody_containsQualityHigh() {
        let body = OpenAIImageGenerator.multipartBody(
            boundary: "B",
            prompt: "p",
            images: [Data([0x01]), Data([0x02])],
            n: 1
        )
        let str = String(data: body, encoding: .utf8) ?? ""
        XCTAssertTrue(str.contains("name=\"quality\""), "must include quality field")
        XCTAssertTrue(str.contains("\r\n\r\nhigh\r\n"), "quality value must be high")
    }

    func test_multipartBody_imageFieldUsesArrayBracketsForMultiple() {
        // OpenAIの /v1/images/edits は同一フィールドの重複を400で拒否する。
        // 複数枚送る時は `image[]` 配列記法を使う必要がある。
        let body = OpenAIImageGenerator.multipartBody(
            boundary: "B",
            prompt: "p",
            images: [Data([0x01]), Data([0x02])],
            n: 1
        )
        let str = String(data: body, encoding: .utf8) ?? ""
        let bracketedCount = str.components(separatedBy: "name=\"image[]\"").count - 1
        XCTAssertEqual(bracketedCount, 2, "複数画像時は name=\"image[]\" を画像ごとに出すこと")
        let nonBracketedCount = str.components(separatedBy: "name=\"image\";").count - 1
        XCTAssertEqual(nonBracketedCount, 0,
                       "重複拒否を避けるため bracket無しの image フィールドは出さない")
    }

    func test_multipartBody_includesPromptAndN() {
        let body = OpenAIImageGenerator.multipartBody(
            boundary: "B",
            prompt: "hello-prompt",
            images: [Data([0x01])],
            n: 3
        )
        let str = String(data: body, encoding: .utf8) ?? ""
        XCTAssertTrue(str.contains("hello-prompt"))
        XCTAssertTrue(str.contains("name=\"n\""))
        XCTAssertTrue(str.contains("\r\n\r\n3\r\n"))
    }

    func test_multipartBody_includesSize1024() {
        let body = OpenAIImageGenerator.multipartBody(
            boundary: "B",
            prompt: "p",
            images: [Data([0x01])],
            n: 1
        )
        let str = String(data: body, encoding: .utf8) ?? ""
        XCTAssertTrue(str.contains("name=\"size\""))
        XCTAssertTrue(str.contains("1024x1024"))
    }

    func test_parseResponse_decodesB64Image() throws {
        let onePixelPNG = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==")!
        let payload: [String: Any] = [
            "data": [
                ["b64_json": onePixelPNG.base64EncodedString()]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let images = try OpenAIImageGenerator.parseResponse(data)
        XCTAssertEqual(images.count, 1)
        XCTAssertEqual(images[0].size.width, 1, accuracy: 0.1)
    }

    func test_parseResponse_emptyDataArray_throws() throws {
        let payload: [String: Any] = ["data": []]
        let data = try JSONSerialization.data(withJSONObject: payload)
        XCTAssertThrowsError(try OpenAIImageGenerator.parseResponse(data)) { error in
            if case ImageGenerationError.noImageReturned = error {
                // expected
            } else {
                XCTFail("Expected noImageReturned, got \(error)")
            }
        }
    }

    func test_generate_missingKey_throws() async {
        let generator = OpenAIImageGenerator(apiKey: "")
        let req = GenerationRequest(
            fatherImageData: Data([0x01]),
            motherImageData: Data([0x02]),
            gender: .unspecified
        )
        do {
            _ = try await generator.generate(request: req, prompt: "p", count: 1)
            XCTFail("Should have thrown")
        } catch {
            if case ImageGenerationError.missingAPIKey = error {
                // expected
            } else {
                XCTFail("Expected missingAPIKey, got \(error)")
            }
        }
    }

    func test_generate_placeholderKey_throws() async {
        let generator = OpenAIImageGenerator(apiKey: "REPLACE_WITH_YOUR_OPENAI_KEY_OR_EMPTY")
        let req = GenerationRequest(
            fatherImageData: Data([0x01]),
            motherImageData: Data([0x02]),
            gender: .unspecified
        )
        do {
            _ = try await generator.generate(request: req, prompt: "p", count: 1)
            XCTFail("Should have thrown")
        } catch {
            if case ImageGenerationError.missingAPIKey = error {
                // expected
            } else {
                XCTFail("Expected missingAPIKey, got \(error)")
            }
        }
    }
}
