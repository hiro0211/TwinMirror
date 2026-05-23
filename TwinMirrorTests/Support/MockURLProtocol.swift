import Foundation

/// Test-only URLProtocol that lets a test register a handler closure for
/// matching requests. Install by adding this class to a URLSessionConfiguration's
/// `protocolClasses` array and constructing a URLSession from it.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    static let lock = NSLock()
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data)) = { _ in
        throw NSError(domain: "MockURLProtocol", code: -1, userInfo: [NSLocalizedDescriptionKey: "no handler set"])
    }

    static func setHandler(_ h: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)) {
        lock.lock(); defer { lock.unlock() }
        handler = h
    }

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let (response, data) = try MockURLProtocol.handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
