import Foundation

@testable import ArtazzenCore

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

final class TestCredentialStore: CredentialStore {
    var values: [String: String] = [:]
    var failWrites = false
    func read(key: String) throws -> String? { values[key] }
    func write(_ password: String, key: String) throws {
        if failWrites { throw CredentialError.storageFailed }
        values[key] = password
    }
}

actor RequestGate {
    private var released = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        if released { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func release() {
        released = true
        for waiter in waiters { waiter.resume() }
        waiters = []
    }
}

actor TestServer {
    struct Reply: Sendable {
        var status = 200
        var json: String
        var gate: RequestGate?
    }
    private var replies: [String: [Reply]] = [:]
    private var requests: [URLRequest] = []
    private var observers: [(Int, CheckedContinuation<Void, Never>)] = []

    func enqueue(_ path: String, _ reply: Reply) { replies[path, default: []].append(reply) }
    func recorded() -> [URLRequest] { requests }
    func waitForRequests(_ count: Int) async {
        if requests.count >= count { return }
        await withCheckedContinuation { observers.append((count, $0)) }
    }

    func respond(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let ready = observers.filter { $0.0 <= requests.count }
        observers.removeAll { $0.0 <= requests.count }
        for observer in ready { observer.1.resume() }
        let path = request.url!.path
        let reply: Reply
        if !(replies[path] ?? []).isEmpty {
            reply = replies[path]!.removeFirst()
        } else {
            switch path {
            case "/admin/api/new-files":
                reply = Reply(
                    json:
                        #"{"pending":[{"name":"a.jpg","url":"/images/a.jpg","metadata":{"title":"Original"}}],"gallery":[]}"#
                )
            case "/admin/api/collections":
                reply = Reply(json: #"{"collections":[]}"#)
            case "/admin/config":
                reply = Reply(
                    json:
                        #"{"ai":{"enabled":true,"model":"server-model","temperature":0.4,"max_output_tokens":500}}"#
                )
            default: reply = Reply(json: "{}")
            }
        }
        if let gate = reply.gate { await gate.wait() }
        let response = HTTPURLResponse(
            url: request.url!, statusCode: reply.status, httpVersion: nil, headerFields: nil)!
        return (Data(reply.json.utf8), response)
    }
}
