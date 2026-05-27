import XCTest
@testable import TwinMirror

final class HistoryServiceTests: XCTestCase {
    private let workerURL = URL(string: "https://worker.example.com")!
    private let token = "test-token"
    private let deviceID = "11111111-1111-4111-8111-111111111111"

    private func makeService(session: URLSession? = nil) -> HistoryService {
        HistoryService(
            workerURL: workerURL,
            authToken: token,
            deviceID: deviceID,
            session: session ?? MockURLProtocol.makeSession()
        )
    }

    // MARK: - save

    func test_save_postsToHistoryWithAuthAndDeviceHeaders() async throws {
        let captured = CapturedRequest()
        MockURLProtocol.setHandler { request in
            captured.set(request)
            let body = """
            {"id":"abc","createdAt":1716000000000,"gender":"female","age":"5","mode":"premium","style":"photorealistic","ratio":"50_50","prompt":"p"}
            """.data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, body)
        }

        let service = makeService()
        let metadata = HistoryMetadata(
            gender: "female", age: "5", mode: "premium",
            style: "photorealistic", ratio: "50_50", prompt: "p"
        )
        let item = try await service.save(
            imageJPEG: Data([0xFF, 0xD8, 0xFF, 0xD9]),
            thumbnailJPEG: Data([0xFF, 0xD8, 0xFF, 0xD9]),
            metadata: metadata,
            isPremium: true
        )

        XCTAssertEqual(item.id, "abc")
        XCTAssertEqual(item.gender, "female")

        let req = try XCTUnwrap(captured.get())
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertEqual(req.url?.path, "/history")
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Auth-Token"), token)
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Device-Id"), deviceID)
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Is-Premium"), "true")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func test_save_includesBase64ImageAndMetadata() async throws {
        let captured = CapturedRequest()
        MockURLProtocol.setHandler { request in
            captured.set(request)
            let body = #"{"id":"abc","createdAt":0}"#.data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!, body)
        }

        let service = makeService()
        let image = Data([0xFF, 0xD8, 0xFF, 0xD9])
        let thumb = Data([0x01, 0x02, 0x03])
        _ = try await service.save(
            imageJPEG: image,
            thumbnailJPEG: thumb,
            metadata: HistoryMetadata(gender: "male", age: "10", mode: "fast", style: "photorealistic", ratio: nil, prompt: "child"),
            isPremium: false
        )

        let req = try XCTUnwrap(captured.get())
        let body = try XCTUnwrap(captured.getBody())
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["image"] as? String, image.base64EncodedString())
        XCTAssertEqual(json["thumbnail"] as? String, thumb.base64EncodedString())
        XCTAssertEqual(json["gender"] as? String, "male")
        XCTAssertEqual(json["age"] as? String, "10")
        XCTAssertEqual(json["mode"] as? String, "fast")
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Is-Premium"), "false")
    }

    func test_save_throwsOnNon2xx() async throws {
        MockURLProtocol.setHandler { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }
        let service = makeService()
        do {
            _ = try await service.save(
                imageJPEG: Data([0x1]), thumbnailJPEG: Data([0x1]),
                metadata: HistoryMetadata(gender: nil, age: nil, mode: nil, style: nil, ratio: nil, prompt: nil),
                isPremium: false
            )
            XCTFail("expected throw")
        } catch HistoryServiceError.requestFailed(let status, _) {
            XCTAssertEqual(status, 500)
        }
    }

    // MARK: - list

    func test_list_parsesItemsAndFlags() async throws {
        MockURLProtocol.setHandler { request in
            let body = #"""
            {"items":[
              {"id":"a","createdAt":3000,"gender":null,"age":null,"mode":null,"style":null,"ratio":null,"prompt":null},
              {"id":"b","createdAt":2000,"gender":null,"age":null,"mode":null,"style":null,"ratio":null,"prompt":null},
              {"id":"c","createdAt":1000,"gender":null,"age":null,"mode":null,"style":null,"ratio":null,"prompt":null}
            ],"totalCount":5,"freeLimitReached":true}
            """#.data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }

        let service = makeService()
        let result = try await service.list(isPremium: false)

        XCTAssertEqual(result.items.count, 3)
        XCTAssertEqual(result.totalCount, 5)
        XCTAssertTrue(result.freeLimitReached)
        XCTAssertEqual(result.items.first?.id, "a")
    }

    func test_list_sendsPremiumHeaderTrue() async throws {
        let captured = CapturedRequest()
        MockURLProtocol.setHandler { request in
            captured.set(request)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    #"{"items":[],"totalCount":0,"freeLimitReached":false}"#.data(using: .utf8)!)
        }
        let service = makeService()
        _ = try await service.list(isPremium: true)

        let req = try XCTUnwrap(captured.get())
        XCTAssertEqual(req.httpMethod, "GET")
        XCTAssertEqual(req.url?.path, "/history")
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Is-Premium"), "true")
    }

    // MARK: - imageData

    func test_imageData_fetchesOriginalByDefault() async throws {
        let captured = CapturedRequest()
        MockURLProtocol.setHandler { request in
            captured.set(request)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "image/jpeg"])!,
                    Data([0xAA, 0xBB]))
        }
        let service = makeService()
        let data = try await service.imageData(for: "abc", variant: .original, isPremium: true)
        XCTAssertEqual(data, Data([0xAA, 0xBB]))
        let req = try XCTUnwrap(captured.get())
        XCTAssertEqual(req.url?.path, "/history/abc/image")
        XCTAssertNil(req.url?.query)
    }

    func test_imageData_thumbnailIncludesVariantQuery() async throws {
        let captured = CapturedRequest()
        MockURLProtocol.setHandler { request in
            captured.set(request)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data())
        }
        let service = makeService()
        _ = try? await service.imageData(for: "abc", variant: .thumb, isPremium: false)
        let req = try XCTUnwrap(captured.get())
        XCTAssertEqual(req.url?.query, "variant=thumb")
    }

    // MARK: - delete

    func test_delete_sendsDELETE() async throws {
        let captured = CapturedRequest()
        MockURLProtocol.setHandler { request in
            captured.set(request)
            return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }
        let service = makeService()
        try await service.delete(id: "abc", isPremium: false)
        let req = try XCTUnwrap(captured.get())
        XCTAssertEqual(req.httpMethod, "DELETE")
        XCTAssertEqual(req.url?.path, "/history/abc")
    }

    func test_delete_throwsOnNon2xx() async {
        MockURLProtocol.setHandler { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
        }
        let service = makeService()
        do {
            try await service.delete(id: "abc", isPremium: false)
            XCTFail("expected throw")
        } catch HistoryServiceError.requestFailed(let status, _) {
            XCTAssertEqual(status, 404)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - deleteAll

    func test_deleteAll_sendsDELETEToCollection() async throws {
        let captured = CapturedRequest()
        MockURLProtocol.setHandler { request in
            captured.set(request)
            return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }
        let service = makeService()
        try await service.deleteAll(isPremium: true)
        let req = try XCTUnwrap(captured.get())
        XCTAssertEqual(req.httpMethod, "DELETE")
        XCTAssertEqual(req.url?.path, "/history")
        XCTAssertNil(req.url?.query)
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Auth-Token"), token)
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Device-Id"), deviceID)
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-Is-Premium"), "true")
    }

    func test_deleteAll_throwsOnNon2xx() async {
        MockURLProtocol.setHandler { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }
        let service = makeService()
        do {
            try await service.deleteAll(isPremium: false)
            XCTFail("expected throw")
        } catch HistoryServiceError.requestFailed(let status, _) {
            XCTAssertEqual(status, 500)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}

// MARK: - helpers

private final class CapturedRequest: @unchecked Sendable {
    private let lock = NSLock()
    private var request: URLRequest?
    private var body: Data?

    func set(_ r: URLRequest) {
        lock.lock(); defer { lock.unlock() }
        request = r
        // URLRequest delivered to URLProtocol carries body via httpBodyStream when set
        // via URLSession.uploadTask. For data tasks with httpBody we read from `r.httpBody`,
        // but URLSession swaps in a stream → drain it.
        if let stream = r.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var data = Data()
            let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
            defer { buf.deallocate() }
            while stream.hasBytesAvailable {
                let n = stream.read(buf, maxLength: 4096)
                if n <= 0 { break }
                data.append(buf, count: n)
            }
            body = data
        } else if let b = r.httpBody {
            body = b
        }
    }

    func get() -> URLRequest? {
        lock.lock(); defer { lock.unlock() }
        return request
    }

    func getBody() -> Data? {
        lock.lock(); defer { lock.unlock() }
        return body
    }
}
