import Foundation
import SwiftUI
import FitCheckShared

/// No cloud relay: a temporary, user-started session on a trusted local network.
struct PairedShoppingSnapshot {
    let revision: Int64
    let products: [Product]
    let selectedProductId: String?

    static func decode(_ data: Data) throws -> PairedShoppingSnapshot {
        guard data.count <= 1_000_000,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["schemaVersion"] as? Int == 1,
              let revision = object["revision"] as? Int64, revision >= 0,
              let values = object["products"] as? [[String: Any]], values.count <= 50 else {
            throw PairingError.invalidResponse
        }
        let encoded = try JSONSerialization.data(withJSONObject: values)
        let products = RoomBridge().decodeProducts(text: String(decoding: encoded, as: UTF8.self))
        guard products.count == values.count,
              Set(products.map(\.id)).count == products.count,
              products.allSatisfy({ !$0.id.isEmpty && $0.id.count <= 300 && $0.title.count <= 2000 && $0.url.count <= 4096 }) else {
            throw PairingError.invalidResponse
        }
        let selected = object["selectedProductId"] as? String
        guard selected == nil || products.contains(where: { $0.id == selected }) else { throw PairingError.invalidResponse }
        return PairedShoppingSnapshot(revision: revision, products: products, selectedProductId: selected)
    }
}

enum PairingError: LocalizedError {
    case invalidLink, invalidResponse, disconnected
    var errorDescription: String? {
        switch self {
        case .invalidLink: return "Paste the complete local pairing link shown by RoomWise on your desktop."
        case .invalidResponse: return "The paired computer returned an invalid RoomWise session."
        case .disconnected: return "Pairing unavailable. Keep both devices on the same Wi-Fi and check the desktop firewall."
        }
    }
}

enum PairingLink {
    static func validate(_ text: String) throws -> URL {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "http", let host = url.host?.lowercased(),
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              let port = url.port, (1024...65535).contains(port),
              url.path.range(of: "^/session/[a-f0-9]{32}$", options: .regularExpression) != nil else { throw PairingError.invalidLink }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        let parts = labels.compactMap { label -> Int? in
            guard !label.isEmpty, label.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
            guard let value = Int(label), String(value) == label else { return nil }
            return value
        }
        let localIPv4 = labels.count == 4 && parts.count == 4 && parts.allSatisfy { (0...255).contains($0) } &&
            (parts[0] == 10 || parts[0] == 127 || (parts[0] == 192 && parts[1] == 168) ||
             (parts[0] == 172 && (16...31).contains(parts[1])) || (parts[0] == 169 && parts[1] == 254))
        let localName = host.hasSuffix(".local") && host.range(of: "^[a-z0-9][a-z0-9.-]*\\.local$", options: .regularExpression) != nil
        guard localIPv4 || localName else { throw PairingError.invalidLink }
        return url
    }
}

private final class LocalPairingTransport: NSObject, URLSessionTaskDelegate, HTTPTransport {
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 4
        config.httpShouldSetCookies = false
        config.urlCache = nil
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    func send(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw PairingError.invalidResponse }
        return (data, response)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil) // Never forward a private pairing token to a redirect.
    }
}

@MainActor final class LivePhoneSession: ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var isPairing = false
    @Published private(set) var status = "Not paired"
    @Published private(set) var revision: Int64 = -1
    private(set) var products: [Product] = []
    private(set) var selectedProductId: String?
    private var endpoint: URL?
    private var task: Task<Void, Never>?
    private var selectionTask: Task<Void, Never>?
    private var generation = UUID()
    private var pendingSelection: String?
    private var selectionStarted = Date.distantPast
    private let transport: HTTPTransport
    init(transport: HTTPTransport? = nil) { self.transport = transport ?? LocalPairingTransport() }

    func connect(link: String) {
        disconnect()
        do { endpoint = try PairingLink.validate(link) }
        catch { status = error.localizedDescription; return }
        let current = generation
        isPairing = true
        status = "Connecting to desktop…"
        task = Task { [weak self] in
            var failures = 0
            while !Task.isCancelled {
                guard let self, self.generation == current, let endpoint = self.endpoint else { return }
                do {
                    var request = URLRequest(url: endpoint)
                    request.cachePolicy = .reloadIgnoringLocalCacheData
                    let (data, response) = try await self.transport.send(request: request)
                    try Task.checkCancellation()
                    guard self.generation == current else { return }
                    guard response.statusCode == 200 else { throw PairingError.disconnected }
                    let snapshot = try PairedShoppingSnapshot.decode(data)
                    failures = 0
                    let recovering = !self.isConnected
                    self.isConnected = true
                    self.isPairing = false
                    self.status = "Live with desktop · local Wi-Fi"
                    if let pending = self.pendingSelection, snapshot.selectedProductId != pending,
                       (self.selectionTask != nil || Date().timeIntervalSince(self.selectionStarted) < 2) {
                        // A poll started before the selection POST must not roll the phone back.
                    } else if snapshot.revision > self.revision || recovering {
                        self.pendingSelection = nil
                        self.products = snapshot.products
                        self.selectedProductId = snapshot.selectedProductId
                        self.revision = snapshot.revision
                    }
                } catch is CancellationError { return }
                catch {
                    guard self.generation == current else { return }
                    failures += 1
                    self.isConnected = false
                    self.status = "Connection interrupted · preview is the last received item"
                    if failures >= 3 {
                        self.isPairing = false
                        self.endpoint = nil
                        self.status = "Disconnected. Start pairing again on the same Wi-Fi."
                        return
                    }
                }
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }
    }

    func selectProduct(_ id: String) {
        guard isConnected, id != (pendingSelection ?? selectedProductId), products.contains(where: { $0.id == id }), endpoint != nil else { return }
        pendingSelection = id
        selectionStarted = Date()
        guard selectionTask == nil else { return }
        let current = generation
        selectionTask = Task {
            while !Task.isCancelled, generation == current, let target = pendingSelection, let endpoint {
                do {
                    var request = URLRequest(url: endpoint.appendingPathComponent("selection"))
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONSerialization.data(withJSONObject: ["productId": target])
                    let (_, response) = try await transport.send(request: request)
                    try Task.checkCancellation()
                    guard generation == current else { return }
                    guard response.statusCode == 200 else { throw PairingError.disconnected }
                    selectionStarted = Date()
                    if pendingSelection == target { break }
                    // A later swipe superseded this request. Send that selection next.
                } catch {
                    guard generation == current else { return }
                    pendingSelection = nil
                    status = "Selection could not reach desktop. Reconnect to continue."
                    break
                }
            }
            guard generation == current else { return }
            selectionTask = nil
        }
    }

    func disconnect() {
        generation = UUID()
        task?.cancel(); task = nil; selectionTask?.cancel(); selectionTask = nil; endpoint = nil
        isConnected = false; isPairing = false; revision = -1
        pendingSelection = nil; products = []; selectedProductId = nil
        status = "Not paired"
    }
}

struct PhonePairingSheet: View {
    @ObservedObject var session: LivePhoneSession
    let onConnect: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var link = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("Browse on desktop, preview on phone") {
                    Text("On RoomWise desktop choose Pair phone → Start pairing. Put both devices on the same trusted Wi-Fi, then paste its pairing link here.")
                    TextField("http://192.168.…/session/…", text: $link)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    Button("Connect") { onConnect(); session.connect(link: link); link = "" }
                        .disabled(link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Section {
                    Text(session.status)
                    Text("Swiping a product page on either screen changes both selections. Your room stays on this phone. The temporary unencrypted link shares product details only; anyone with it on the network can change the selection. Stop pairing when finished. No provider keys or chat are shared.")
                        .font(.caption)
                    if session.isConnected || session.isPairing { Button("Disconnect", role: .destructive) { session.disconnect() } }
                }
            }
            .navigationTitle("Pair with desktop")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
