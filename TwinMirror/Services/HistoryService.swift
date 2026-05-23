import Foundation

enum HistoryImageVariant: String, Sendable {
    case original
    case thumb
}

enum HistoryServiceError: Error, Equatable {
    case missingAuthToken
    case missingWorkerURL
    case requestFailed(statusCode: Int, body: String)
    case decodingFailed
}

protocol HistoryServicing: Sendable {
    func save(
        imageJPEG: Data,
        thumbnailJPEG: Data,
        metadata: HistoryMetadata,
        isPremium: Bool
    ) async throws -> HistoryItem
    func list(isPremium: Bool) async throws -> HistoryListResponse
    func imageData(for id: String, variant: HistoryImageVariant, isPremium: Bool) async throws -> Data
    func delete(id: String, isPremium: Bool) async throws
}

struct HistoryService: HistoryServicing {
    let workerURL: URL
    let authToken: String
    let deviceID: String
    let session: URLSession

    init(workerURL: URL, authToken: String, deviceID: String, session: URLSession = .shared) {
        self.workerURL = workerURL
        self.authToken = authToken
        self.deviceID = deviceID
        self.session = session
    }

    func save(
        imageJPEG: Data,
        thumbnailJPEG: Data,
        metadata: HistoryMetadata,
        isPremium: Bool
    ) async throws -> HistoryItem {
        var request = makeRequest(path: "history", method: "POST", isPremium: isPremium)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = [
            "image": imageJPEG.base64EncodedString(),
            "thumbnail": thumbnailJPEG.base64EncodedString(),
        ]
        if let v = metadata.gender { payload["gender"] = v }
        if let v = metadata.age { payload["age"] = v }
        if let v = metadata.mode { payload["mode"] = v }
        if let v = metadata.style { payload["style"] = v }
        if let v = metadata.ratio { payload["ratio"] = v }
        if let v = metadata.prompt { payload["prompt"] = v }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let data = try await send(request)
        return try decode(HistoryItem.self, from: data)
    }

    func list(isPremium: Bool) async throws -> HistoryListResponse {
        let request = makeRequest(path: "history", method: "GET", isPremium: isPremium)
        let data = try await send(request)
        return try decode(HistoryListResponse.self, from: data)
    }

    func imageData(for id: String, variant: HistoryImageVariant, isPremium: Bool) async throws -> Data {
        let query = variant == .thumb ? "variant=thumb" : nil
        let request = makeRequest(path: "history/\(id)/image", method: "GET", query: query, isPremium: isPremium)
        return try await send(request)
    }

    func delete(id: String, isPremium: Bool) async throws {
        let request = makeRequest(path: "history/\(id)", method: "DELETE", isPremium: isPremium)
        _ = try await send(request)
    }

    // MARK: - Private

    private func makeRequest(path: String, method: String, query: String? = nil, isPremium: Bool) -> URLRequest {
        var url = workerURL.appendingPathComponent(path)
        if let query, !query.isEmpty {
            var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            comps?.query = query
            if let withQuery = comps?.url { url = withQuery }
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(authToken, forHTTPHeaderField: "X-Auth-Token")
        req.setValue(deviceID, forHTTPHeaderField: "X-Device-Id")
        req.setValue(isPremium ? "true" : "false", forHTTPHeaderField: "X-Is-Premium")
        req.timeoutInterval = 30
        return req
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HistoryServiceError.requestFailed(statusCode: -1, body: "no HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw HistoryServiceError.requestFailed(statusCode: http.statusCode, body: body)
        }
        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw HistoryServiceError.decodingFailed
        }
    }
}

extension HistoryService {
    /// Construct from `AppConfig` and the persistent device identity. Returns `nil`
    /// when the worker URL or auth token is not configured (e.g. missing xcconfig).
    static func makeDefault() -> HistoryService? {
        guard let url = AppConfig.workerURL else { return nil }
        let token = AppConfig.workerAuthToken
        guard !token.isEmpty else { return nil }
        return HistoryService(
            workerURL: url,
            authToken: token,
            deviceID: DeviceIdentity.shared.deviceID
        )
    }
}
