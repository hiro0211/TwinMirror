import XCTest
@testable import TwinMirror

final class GeminiImageGeneratorTests: XCTestCase {

    private let workerURL = URL(string: "https://worker.example.com")!

    func test_buildRequestBody_includesModelPromptAndTwoImages() throws {
        let generator = GeminiImageGenerator(workerURL: workerURL, authToken: "tok", model: .nanoBanana2)
        let body = try generator.buildRequestBody(
            prompt: "Test prompt",
            fatherJPEG: Data([0xFF, 0xD8, 0xFF]),
            motherJPEG: Data([0xFF, 0xD8, 0xFE])
        )

        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "gemini-3.1-flash-image-preview")

        let contents = try XCTUnwrap(json["contents"] as? [[String: Any]])
        let parts = try XCTUnwrap(contents.first?["parts"] as? [[String: Any]])

        XCTAssertEqual(parts.count, 3, "Should have 1 text part + 2 image parts")
        XCTAssertEqual(parts[0]["text"] as? String, "Test prompt")

        let firstImage = try XCTUnwrap(parts[1]["inline_data"] as? [String: Any])
        XCTAssertEqual(firstImage["mime_type"] as? String, "image/jpeg")
        XCTAssertNotNil(firstImage["data"])
    }

    func test_buildRequestBody_includesSafetySettings() throws {
        let generator = GeminiImageGenerator(workerURL: workerURL, authToken: "tok")
        let body = try generator.buildRequestBody(
            prompt: "p",
            fatherJPEG: Data([0x01]),
            motherJPEG: Data([0x02])
        )
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let safety = try XCTUnwrap(json["safetySettings"] as? [[String: String]])
        XCTAssertFalse(safety.isEmpty)
    }

    func test_parseResponse_extractsBase64Image() throws {
        let onePixelPNG = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==")!
        let payload: [String: Any] = [
            "candidates": [[
                "content": [
                    "parts": [
                        ["inline_data": [
                            "mime_type": "image/png",
                            "data": onePixelPNG.base64EncodedString()
                        ]]
                    ]
                ]
            ]]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)

        let image = try GeminiImageGenerator.parseResponse(data)
        XCTAssertEqual(image.size.width, 1, accuracy: 0.1)
        XCTAssertEqual(image.size.height, 1, accuracy: 0.1)
    }

    func test_parseResponse_safetyBlock_throws() throws {
        let payload: [String: Any] = [
            "promptFeedback": ["blockReason": "SAFETY"]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)

        XCTAssertThrowsError(try GeminiImageGenerator.parseResponse(data)) { error in
            if case ImageGenerationError.safetyBlocked = error {
                // expected
            } else {
                XCTFail("Expected safetyBlocked, got \(error)")
            }
        }
    }

    func test_parseResponse_finishReasonSAFETY_throws() throws {
        let payload: [String: Any] = [
            "candidates": [[
                "finishReason": "SAFETY",
                "content": ["parts": []]
            ]]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)

        XCTAssertThrowsError(try GeminiImageGenerator.parseResponse(data)) { error in
            if case ImageGenerationError.safetyBlocked = error {
                // expected
            } else {
                XCTFail("Expected safetyBlocked, got \(error)")
            }
        }
    }

    func test_parseResponse_emptyCandidates_throws() throws {
        let payload: [String: Any] = ["candidates": []]
        let data = try JSONSerialization.data(withJSONObject: payload)

        XCTAssertThrowsError(try GeminiImageGenerator.parseResponse(data)) { error in
            if case ImageGenerationError.noImageReturned = error {
                // expected
            } else {
                XCTFail("Expected noImageReturned, got \(error)")
            }
        }
    }

    func test_generate_missingAuthToken_throws() async {
        let generator = GeminiImageGenerator(workerURL: workerURL, authToken: "")
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
