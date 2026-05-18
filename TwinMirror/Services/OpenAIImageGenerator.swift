import Foundation
import UIKit

struct OpenAIImageGenerator: ImageGenerator {
    let apiKey: String
    let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func generate(request: GenerationRequest, prompt: String, count: Int) async throws -> [UIImage] {
        guard !apiKey.isEmpty, apiKey != "REPLACE_WITH_YOUR_OPENAI_KEY_OR_EMPTY" else {
            throw ImageGenerationError.missingAPIKey
        }
        // OpenAI gpt-image-2 (April 2026) supports multi-image reference via the
        // /v1/images/edits multipart endpoint with multiple image[] fields.
        // For MVP we send a single request asking for `count` images.
        let url = URL(string: "https://api.openai.com/v1/images/edits")!
        let boundary = "----TwinMirror-\(UUID().uuidString)"
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 90
        urlRequest.httpBody = Self.multipartBody(
            boundary: boundary,
            prompt: prompt,
            images: [request.fatherImageData, request.motherImageData],
            n: count
        )

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

    static func multipartBody(boundary: String, prompt: String, images: [Data], n: Int) -> Data {
        var body = Data()
        func append(_ str: String) { body.append(str.data(using: .utf8) ?? Data()) }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        append("gpt-image-2\r\n")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n")
        append("\(prompt)\r\n")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"n\"\r\n\r\n")
        append("\(n)\r\n")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"size\"\r\n\r\n")
        append("1024x1024\r\n")

        for (i, imageData) in images.enumerated() {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"image[]\"; filename=\"ref_\(i).jpg\"\r\n")
            append("Content-Type: image/jpeg\r\n\r\n")
            body.append(imageData)
            append("\r\n")
        }
        append("--\(boundary)--\r\n")
        return body
    }

    static func parseResponse(_ data: Data) throws -> [UIImage] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]] else {
            throw ImageGenerationError.decodingFailed
        }
        var images: [UIImage] = []
        for item in dataArray {
            if let b64 = item["b64_json"] as? String,
               let bytes = Data(base64Encoded: b64),
               let image = UIImage(data: bytes) {
                images.append(image)
            }
        }
        if images.isEmpty { throw ImageGenerationError.noImageReturned }
        return images
    }
}
