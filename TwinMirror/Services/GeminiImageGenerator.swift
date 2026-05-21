import Foundation
import UIKit

struct GeminiImageGenerator: ImageGenerator {
    enum Model: String {
        case nanoBanana2 = "gemini-3.1-flash-image-preview"
        case stable25    = "gemini-2.5-flash-image"
    }

    let workerURL: URL
    let authToken: String
    let model: Model
    let session: URLSession

    init(workerURL: URL, authToken: String, model: Model = .nanoBanana2, session: URLSession = .shared) {
        self.workerURL = workerURL
        self.authToken = authToken
        self.model = model
        self.session = session
    }

    func generate(request: GenerationRequest, prompt: String) async throws -> UIImage {
        guard !authToken.isEmpty else {
            throw ImageGenerationError.missingAPIKey
        }
        return try await singleRequest(request: request, prompt: prompt)
    }

    func buildRequestBody(prompt: String, fatherJPEG: Data, motherJPEG: Data) throws -> Data {
        let body: [String: Any] = [
            "model": model.rawValue,
            "contents": [[
                "parts": [
                    ["text": prompt],
                    ["inline_data": [
                        "mime_type": "image/jpeg",
                        "data": fatherJPEG.base64EncodedString()
                    ]],
                    ["inline_data": [
                        "mime_type": "image/jpeg",
                        "data": motherJPEG.base64EncodedString()
                    ]]
                ]
            ]],
            "generationConfig": [
                "responseModalities": ["IMAGE"]
            ],
            "safetySettings": [
                ["category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_ONLY_HIGH"],
                ["category": "HARM_CATEGORY_HATE_SPEECH",       "threshold": "BLOCK_ONLY_HIGH"],
                ["category": "HARM_CATEGORY_HARASSMENT",        "threshold": "BLOCK_ONLY_HIGH"],
                ["category": "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold": "BLOCK_LOW_AND_ABOVE"]
            ]
        ]
        return try JSONSerialization.data(withJSONObject: body)
    }

    private func singleRequest(request: GenerationRequest, prompt: String) async throws -> UIImage {
        let url = workerURL.appendingPathComponent("generate")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(authToken, forHTTPHeaderField: "X-Auth-Token")
        urlRequest.httpBody = try buildRequestBody(
            prompt: prompt,
            fatherJPEG: request.fatherImageData,
            motherJPEG: request.motherImageData
        )
        urlRequest.timeoutInterval = 60

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw ImageGenerationError.requestFailed(statusCode: -1, body: "No HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ImageGenerationError.requestFailed(statusCode: http.statusCode, body: body)
        }

        return try Self.parseResponse(data)
    }

    static func parseResponse(_ data: Data) throws -> UIImage {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ImageGenerationError.decodingFailed
        }

        if let promptFeedback = json["promptFeedback"] as? [String: Any],
           let blockReason = promptFeedback["blockReason"] as? String {
            throw ImageGenerationError.safetyBlocked(reason: blockReason)
        }

        guard let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first else {
            throw ImageGenerationError.noImageReturned
        }

        if let finishReason = first["finishReason"] as? String,
           finishReason == "SAFETY" || finishReason == "PROHIBITED_CONTENT" || finishReason == "BLOCKLIST" {
            throw ImageGenerationError.safetyBlocked(reason: finishReason)
        }

        guard let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw ImageGenerationError.noImageReturned
        }

        for part in parts {
            if let inlineData = part["inline_data"] as? [String: Any] ?? part["inlineData"] as? [String: Any],
               let base64 = inlineData["data"] as? String,
               let bytes = Data(base64Encoded: base64),
               let image = UIImage(data: bytes) {
                return image
            }
        }
        throw ImageGenerationError.noImageReturned
    }
}
