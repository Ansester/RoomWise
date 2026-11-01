import Foundation
import SwiftUI
import FitCheckShared

enum CredentialSource {
    case keychain
    case debugConfig
    case none
}

/// User-supplied credentials stored only in Keychain or current app memory.
/// Repository Debug configuration never overrides these runtime values.
final class SessionCredentials: ObservableObject {
    // Retained solely for the legacy, non-default shopping implementation.
    @Published var provider: String = "openai"
    @Published var model: String = "gpt-4o"
    @Published var apiKey: String = ""
    @Published var tavilyKey: String = ""
    @Published var groqKey: String = ""
    @Published var groqModel: String = FreeShoppingParser.defaultModel
    @Published var statusMessage: String = ""

    let store: CredentialStore

    init(store: CredentialStore = KeychainCredentialStore()) {
        self.store = store
        reloadPreferredCredentials()
    }

    func reloadPreferredCredentials() {
        apiKey = store.loadOpenAIKey()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        tavilyKey = store.loadTavilyKey()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        groqKey = store.loadGroqKey()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var openAISource: CredentialSource { hasOpenAISaved ? .keychain : .none }
    var tavilySource: CredentialSource { hasTavilySaved ? .keychain : .none }
    var hasOpenAIKey: Bool { !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var hasTavilyKey: Bool { !tavilyKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var hasGroqKey: Bool { !groqKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var hasOpenAISaved: Bool { store.loadOpenAIKey()?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
    var hasTavilySaved: Bool { store.loadTavilyKey()?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }

    var openAIStatus: String {
        hasOpenAISaved ? "OpenAI key saved in Keychain" : (hasOpenAIKey ? "OpenAI key entered" : "Key missing")
    }
    var tavilyStatus: String {
        hasTavilySaved ? "Tavily key saved in Keychain" : (hasTavilyKey ? "Tavily key entered" : "Key missing")
    }
    var groqStatus: String {
        if hasGroqKey, store.loadGroqKey()?.trimmingCharacters(in: .whitespacesAndNewlines) == groqKey.trimmingCharacters(in: .whitespacesAndNewlines) {
            return "Groq key saved in Keychain"
        }
        return hasGroqKey ? "Groq key entered" : "Optional · offline parser available"
    }

    func saveFreeKeys() throws {
        try store.saveGroqKey(groqKey)
        try store.saveTavilyKey(tavilyKey)
        statusMessage = "Groq and Tavily keys saved in device Keychain"
    }

    func clearFreeKeys() throws {
        try store.saveGroqKey("")
        try store.saveTavilyKey("")
        groqKey = ""
        tavilyKey = ""
        statusMessage = "Groq and Tavily keys cleared"
    }

    func saveToKeychain() throws {
        try store.saveOpenAIKey(apiKey)
        try store.saveTavilyKey(tavilyKey)
        try store.saveGroqKey(groqKey)
        statusMessage = "Keys saved securely in device Keychain"
    }

    func clear() throws {
        try store.clear()
        apiKey = ""
        tavilyKey = ""
        groqKey = ""
        statusMessage = ""
    }

    func clearSavedOverrides() throws {
        try clear()
        statusMessage = "Device credentials cleared"
    }

    var hasKeys: Bool { hasOpenAIKey && hasTavilyKey }

    // Validation for legacy ShoppingAgent callers; the free path uses Tavily only
    // and treats Groq as optional, with explicit offline fallback.
    var validationError: String? {
        let p = provider.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard p == "openai" else {
            return "Only OpenAI is supported by the legacy iOS agent. Configured provider '\(provider)' is unsupported."
        }
        if !hasTavilyKey {
            return "Tavily search key is required for retailer retrieval. Configure in Connections."
        }
        if hasOpenAIKey && model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Model ID is required (e.g. gpt-4o)."
        }
        return nil
    }
}

struct SavedSession {
    let room: Room?
    let query: String
    let products: [Product]
    let selectedProductId: String?
    let chairPose: Pose
    let retailerStatuses: [String: String]
    let sampleMode: Bool
}

/// Local persistence of accepted rooms and session state.
enum RoomPersistence {
    private static let savedRoomKey = "roomwise_saved_room_json"
    private static let lastQueryKey = "roomwise_last_search_query"
    private static let savedProductsKey = "roomwise_saved_products_json"
    private static let savedSelectedProductKey = "roomwise_saved_selected_product_id"
    private static let savedChairPoseKey = "roomwise_saved_chair_pose"
    private static let savedStatusesKey = "roomwise_saved_retailer_statuses"
    private static let sampleModeKey = "roomwise_sample_mode"

    static func safeDecodeRoom(json: String) -> Room? {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let validated = RoomBridge().validate(text: trimmed)
        guard !validated.isEmpty else { return nil }
        return RoomBridge().safeDecode(text: validated)
    }

    static func saveRoom(json: String) {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let validated = RoomBridge().validate(text: trimmed)
        guard !validated.isEmpty else { return }
        UserDefaults.standard.set(validated, forKey: savedRoomKey)
    }

    static func loadSavedRoom() -> Room? {
        guard let json = UserDefaults.standard.string(forKey: savedRoomKey), !json.isEmpty else {
            return nil
        }
        return safeDecodeRoom(json: json)
    }

    static func clearSavedRoom() {
        UserDefaults.standard.removeObject(forKey: savedRoomKey)
    }

    static func saveLastQuery(_ query: String) {
        UserDefaults.standard.set(query, forKey: lastQueryKey)
    }

    static func loadLastQuery() -> String {
        UserDefaults.standard.string(forKey: lastQueryKey) ?? "Black office chair with armrests under AED 400"
    }

    static func saveSampleMode(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: sampleModeKey)
    }

    static func loadSampleMode() -> Bool {
        if UserDefaults.standard.object(forKey: sampleModeKey) == nil {
            return true // Default to true on fresh launch
        }
        return UserDefaults.standard.bool(forKey: sampleModeKey)
    }

    static func saveSession(
        room: Room?,
        query: String,
        products: [Product],
        selectedProductId: String?,
        chairPose: Pose,
        retailerStatuses: [String: String],
        sampleMode: Bool
    ) {
        if let room = room {
            let roomJson = RoomBridge().encodeRoom(room: room)
            if !roomJson.isEmpty {
                UserDefaults.standard.set(roomJson, forKey: savedRoomKey)
            }
        }
        UserDefaults.standard.set(query, forKey: lastQueryKey)
        UserDefaults.standard.set(sampleMode, forKey: sampleModeKey)

        let productsJson = RoomBridge().encodeProducts(products: products)
        UserDefaults.standard.set(productsJson, forKey: savedProductsKey)

        if let selectedId = selectedProductId {
            UserDefaults.standard.set(selectedId, forKey: savedSelectedProductKey)
        } else {
            UserDefaults.standard.removeObject(forKey: savedSelectedProductKey)
        }

        let poseDict: [String: Double] = ["x": chairPose.x, "z": chairPose.z, "yaw": chairPose.yaw]
        if let poseData = try? JSONSerialization.data(withJSONObject: poseDict) {
            UserDefaults.standard.set(poseData, forKey: savedChairPoseKey)
        }

        if let statusData = try? JSONSerialization.data(withJSONObject: retailerStatuses) {
            UserDefaults.standard.set(statusData, forKey: savedStatusesKey)
        }
    }

    static func loadSession() -> SavedSession? {
        let room = loadSavedRoom()
        let query = UserDefaults.standard.string(forKey: lastQueryKey) ?? loadLastQuery()
        let sampleMode = loadSampleMode()

        var products: [Product] = []
        if let productsJson = UserDefaults.standard.string(forKey: savedProductsKey), !productsJson.isEmpty {
            let decoded = RoomBridge().decodeProducts(text: productsJson)
            products = decoded.map { p in
                let loadedProvenance: ProductProvenance
                if p.provenance == ProductProvenance.live || p.provenance == ProductProvenance.savedLive {
                    loadedProvenance = ProductProvenance.savedLive
                } else if p.provenance == ProductProvenance.userEntered {
                    loadedProvenance = ProductProvenance.userEntered
                } else {
                    loadedProvenance = ProductProvenance.fixture
                }
                return p.doCopy(
                    id: p.id,
                    retailer: p.retailer,
                    title: p.title,
                    url: p.url,
                    imageUrl: p.imageUrl,
                    price: p.price,
                    currency: p.currency,
                    retrievedAt: p.retrievedAt,
                    variant: p.variant,
                    seller: p.seller,
                    dimensions: p.dimensions,
                    features: p.features,
                    delivery: p.delivery,
                    availability: p.availability,
                    issues: p.issues,
                    source: p.source,
                    savedDemo: loadedProvenance == ProductProvenance.fixture,
                    provenance: loadedProvenance
                )
            }
        }

        let selectedId = UserDefaults.standard.string(forKey: savedSelectedProductKey)

        let selectedProduct = products.first { $0.id == selectedId } ?? products.first
        var pose = GeometryKt.initialPlacement(room: room ?? DemoKt.demoRoom(), d: selectedProduct?.previewSize())
        if let poseData = UserDefaults.standard.data(forKey: savedChairPoseKey),
           let poseDict = (try? JSONSerialization.jsonObject(with: poseData)) as? [String: Double],
           let x = poseDict["x"], let z = poseDict["z"], let yaw = poseDict["yaw"],
           x.isFinite, z.isFinite, yaw.isFinite, abs(x) < 10_000, abs(z) < 10_000 {
            pose = Pose(x: x, z: z, yaw: yaw)
        }

        var statuses: [String: String] = [
            "Amazon UAE": "Pending",
            "Noon UAE": "Pending",
            "Temu": "Pending"
        ]
        if let statusData = UserDefaults.standard.data(forKey: savedStatusesKey),
           let statusDict = (try? JSONSerialization.jsonObject(with: statusData)) as? [String: String] {
            statuses = statusDict
        }

        guard room != nil || !products.isEmpty || UserDefaults.standard.string(forKey: lastQueryKey) != nil else {
            return nil
        }

        return SavedSession(
            room: room,
            query: query,
            products: products,
            selectedProductId: selectedId,
            chairPose: pose,
            retailerStatuses: statuses,
            sampleMode: sampleMode
        )
    }

    static func clearSession() {
        UserDefaults.standard.removeObject(forKey: savedRoomKey)
        UserDefaults.standard.removeObject(forKey: lastQueryKey)
        UserDefaults.standard.removeObject(forKey: savedProductsKey)
        UserDefaults.standard.removeObject(forKey: savedSelectedProductKey)
        UserDefaults.standard.removeObject(forKey: savedChairPoseKey)
        UserDefaults.standard.removeObject(forKey: savedStatusesKey)
        UserDefaults.standard.removeObject(forKey: sampleModeKey)
    }

    /// Deletes all RoomWise room/search state and its temporary share file.
    /// Provider credentials have a separate, explicit Keychain deletion action.
    static func clearSavedData() {
        clearSession()
        let exportURL = FileManager.default.temporaryDirectory.appendingPathComponent("RoomWise-room.json")
        try? FileManager.default.removeItem(at: exportURL)
    }

    /// Exports a validated room to a temporary JSON file for sharing.
    static func createExportFile(for room: Room) -> URL? {
        let roomText = RoomBridge().encodeRoom(room: room)
        let validated = RoomBridge().validate(text: roomText)
        guard !validated.isEmpty, let data = validated.data(using: .utf8) else { return nil }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("RoomWise-room.json")
        do {
            try data.write(to: tempURL, options: .atomic)
            return tempURL
        } catch {
            return nil
        }
    }
}
