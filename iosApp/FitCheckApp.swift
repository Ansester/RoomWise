import SwiftUI
import RoomPlan
import AVFoundation
import simd
import FitCheckShared

private let forestGreen = Color(red: 0.14, green: 0.29, blue: 0.21)
private let sageSurface = Color(red: 0.94, green: 0.95, blue: 0.94)
private let sageBorder = Color(red: 0.86, green: 0.89, blue: 0.87)
private let openingsAmber = Color(red: 0.73, green: 0.41, blue: 0.13)
private let charcoalText = Color(red: 0.09, green: 0.13, blue: 0.11)

extension Product: @retroactive Identifiable {}

@main
struct FitCheckApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
        }
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("roomwise_groq_tavily_search_consent_v2") private var liveSearchConsent = false
    @StateObject private var capture = RoomCaptureController()
    @StateObject private var credentials = SessionCredentials()

    @State private var activeRoom: Room
    @State private var queryText: String
    @State private var sampleMode: Bool = true
    @State private var isSearching: Bool = false
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var activeRequestId: UUID = UUID()

    @State private var searchLogs: [String] = []
    @State private var retailerStatuses: [String: String]
    @State private var products: [Product]
    @State private var selectedProduct: Product?
    @State private var chairPose: Pose

    // Sheets & Dialogs
    @State private var showConnections: Bool = false
    @State private var showScanSheet: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var exportURL: URL? = nil
    @State private var showFileImporter: Bool = false
    @State private var editingProductForDims: Product? = nil
    @State private var detailsProduct: Product? = nil
    @State private var statusBanner: String = ""
    @State private var showSearchDetails: Bool = false
    @State private var showHelp: Bool = false
    @State private var showSearchConsent: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var showAddChair = false

    init() {
        let saved = RoomPersistence.loadSession()
        let initialRoom = saved?.room ?? DemoKt.demoRoom()
        _activeRoom = State(initialValue: initialRoom)
        _queryText = State(initialValue: saved?.query ?? RoomPersistence.loadLastQuery())
        let initialSampleMode = saved?.sampleMode ?? RoomPersistence.loadSampleMode()
        _sampleMode = State(initialValue: initialSampleMode)

        let initialProducts: [Product]
        if let saved = saved {
            initialProducts = saved.products
        } else {
            initialProducts = DemoKt.demoProducts()
        }
        _products = State(initialValue: initialProducts)
        _selectedProduct = State(initialValue: initialProducts.first(where: { $0.id == saved?.selectedProductId }) ?? initialProducts.first)
        _chairPose = State(initialValue: saved?.chairPose ?? GeometryKt.initialPlacement(room: initialRoom, d: initialProducts.first?.previewSize()))
        _retailerStatuses = State(initialValue: saved?.retailerStatuses ?? [
            "Amazon UAE": "Sample fixture",
            "Noon UAE": "Sample fixture",
            "Temu": "Sample fixture"
        ])
        _statusBanner = State(initialValue: saved == nil ? "Sample room · explore offline or scan your own space" : "Saved room and chair selection restored")
    }

    private var productProvenanceBadge: (text: String, color: Color) {
        if sampleMode {
            return ("SAMPLE DATA", forestGreen)
        }
        if products.isEmpty {
            return ("NO LIVE RESULTS", openingsAmber)
        }
        if products.allSatisfy({ $0.provenance == .userEntered }) {
            return ("YOUR CHAIRS", forestGreen)
        }
        if products.allSatisfy({ $0.provenance == ProductProvenance.fixture }) {
            return ("SAMPLE DATA", Color.secondary)
        }
        if products.contains(where: { $0.provenance == ProductProvenance.savedLive }) {
            return ("SAVED LIVE RESULTS", forestGreen)
        }
        return ("LIVE RESULTS", forestGreen)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 1. Header
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("RoomWise")
                                    .font(.title3.bold())
                                    .foregroundColor(forestGreen)
                                Text("—")
                                    .foregroundColor(.secondary)
                                Text(activeRoom.name)
                                    .font(.subheadline)
                                    .foregroundColor(charcoalText)
                                    .lineLimit(1)
                            }
                            HStack(spacing: 6) {
                                if activeRoom.savedDemo {
                                    Text("SAMPLE ROOM")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(sageSurface)
                                        .foregroundColor(.secondary)
                                        .clipShape(Capsule())
                                } else {
                                    let quality = activeRoom.scanQuality()
                                    let label = (quality == ScanQuality.complete) ? "COMPLETE SCAN" : "PARTIAL SCAN"
                                    let col = (quality == ScanQuality.complete) ? forestGreen : openingsAmber
                                    Text(label)
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(sageSurface)
                                        .foregroundColor(col)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        Spacer()
                        Menu {
                            Button(action: { showScanSheet = true }) {
                                Label("Scan room (LiDAR)", systemImage: "viewfinder")
                            }
                            Button(action: {
                                activeRoom = DemoKt.demoRoom()
                                chairPose = GeometryKt.initialPlacement(room: activeRoom, d: selectedProduct?.previewSize())
                                persistCurrentSession()
                                statusBanner = "Sample room loaded"
                            }) {
                                Label("Load sample room", systemImage: "cube.transparent")
                            }
                            Button(action: { showFileImporter = true }) {
                                Label("Import room file", systemImage: "square.and.arrow.down")
                            }
                            Button(action: {
                                if let url = RoomPersistence.createExportFile(for: activeRoom) {
                                    exportURL = url
                                    showShareSheet = true
                                } else {
                                    statusBanner = "Could not export this room. Please try again."
                                }
                            }) {
                                Label("Export room file", systemImage: "square.and.arrow.up")
                            }
                            Divider()
                            Button(action: { cancelSearch(); showConnections = true }) {
                                Label("Connections", systemImage: "key")
                            }
                            Button(action: { showHelp = true }) {
                                Label("Help & Privacy", systemImage: "questionmark.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title3)
                                .foregroundColor(forestGreen)
                                .accessibilityLabel("Room actions")
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)

                    if activeRoom.savedDemo {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Know your space before you buy.")
                                .font(.title2.bold())
                                .foregroundColor(forestGreen)
                            Text("Explore the sample below, or scan your room to check a chair against your walls and furniture.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Button { showScanSheet = true } label: {
                                Label("Scan my room", systemImage: "viewfinder")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(forestGreen)
                            Text("Room scanning requires an iPhone with LiDAR. Import and dimension previews work without it.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(sageSurface, in: RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal)
                    }

                    // 2. Room Floor Plan & Placement Canvas
                    FloorPlanCanvas(
                        room: activeRoom,
                        selectedProduct: selectedProduct,
                        pose: $chairPose,
                        onPoseChange: {
                            chairPose = $0
                            persistCurrentSession()
                        }
                    )
                    .padding(.horizontal)

                    // 3. Shopping Sidebar / Discovery
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Find furniture.")
                                .font(.headline)
                                .foregroundColor(charcoalText)
                            Spacer()
                            Text(productProvenanceBadge.text)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(sageSurface)
                                .foregroundColor(productProvenanceBadge.color)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(productProvenanceBadge.color.opacity(0.3), lineWidth: 1))
                        }
                        Text("Describe the chair you’re looking for.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        // Search Input
                        HStack(spacing: 8) {
                            TextField("e.g. Black office chair with armrests", text: $queryText)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()

                            if isSearching {
                                Button("Cancel") {
                                    cancelSearch()
                                }
                                .buttonStyle(.bordered)
                                .tint(openingsAmber)
                                .controlSize(.regular)
                            } else {
                                Button("Search") {
                                    performSearch()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(forestGreen)
                                .controlSize(.regular)
                                .disabled(queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }

                        // Sample Mode Toggle
                        HStack {
                            Toggle("Sample mode", isOn: Binding(
                                get: { sampleMode },
                                set: { newValue in
                                    cancelSearch()
                                    sampleMode = newValue
                                    products = products.filter { $0.provenance != .fixture } + (newValue ? DemoKt.demoProducts() : [])
                                    selectedProduct = products.first
                                    chairPose = GeometryKt.initialPlacement(room: activeRoom, d: selectedProduct?.previewSize())
                                    retailerStatuses = Dictionary(uniqueKeysWithValues: ["Amazon UAE", "Noon UAE", "Temu"].map { ($0, newValue ? "Sample fixture" : "Ready to search") })
                                    statusBanner = newValue ? "Offline sample chairs loaded" : "Free-tier search uses your own Groq and Tavily accounts. You can also browse retailers directly."
                                    persistCurrentSession()
                                }
                            ))
                            .toggleStyle(SwitchToggleStyle(tint: forestGreen))
                            .font(.subheadline)
                            Spacer()
                            if sampleMode {
                                Text("Offline demo")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Retailer Status Row (3 equal cells)
                        HStack(spacing: 8) {
                            ForEach(["Amazon UAE", "Noon UAE", "Temu"], id: \.self) { store in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store)
                                        .font(.caption2.bold())
                                        .foregroundColor(charcoalText)
                                        .lineLimit(1)
                                    Text(retailerStatuses[store] ?? "Pending")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(sageSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }

                        // Status Banner
                        if !statusBanner.isEmpty {
                            Text(statusBanner)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Your shortlist").font(.headline)
                            Spacer()
                            Button { showAddChair = true } label: {
                                Label("Add chair", systemImage: "plus")
                            }
                            .tint(forestGreen)
                        }
                        if !sampleMode {
                            RetailerSearchLinksView(query: queryText)
                        }

                        // Product Cards Shortlist
                        if products.isEmpty {
                            ContentUnavailableView(
                                "No chairs yet",
                                systemImage: "chair.lounge",
                                description: Text("Search with free-tier keys, browse a retailer, or add a chair using your own measurements.")
                            )
                        }
                        VStack(spacing: 12) {
                            ForEach(products, id: \.id) { product in
                                ProductCardView(
                                    product: product,
                                    isSelected: selectedProduct?.id == product.id,
                                    isLowestPrice: isLowestPrice(product: product),
                                    onPreview: {
                                        selectedProduct = product
                                        chairPose = GeometryKt.initialPlacement(room: activeRoom, d: product.previewSize())
                                        persistCurrentSession()
                                    },
                                    onEditDimensions: {
                                        editingProductForDims = product
                                    },
                                    onDetails: {
                                        detailsProduct = product
                                    }
                                )
                                .contextMenu {
                                    Button("Remove from shortlist", role: .destructive) {
                                        products.removeAll { $0.id == product.id }
                                        if selectedProduct?.id == product.id {
                                            selectedProduct = products.first
                                            chairPose = GeometryKt.initialPlacement(room: activeRoom, d: selectedProduct?.previewSize())
                                        }
                                        persistCurrentSession()
                                    }
                                }
                            }
                        }

                        // Collapsible Search Details
                        DisclosureGroup("Search details (\(searchLogs.count))", isExpanded: $showSearchDetails) {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(searchLogs, id: \.self) { log in
                                    Text("• \(log)")
                                        .font(.caption2.monospaced())
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                        }
                        .font(.caption)
                        .foregroundColor(forestGreen)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showScanSheet) {
                ScanSheetView(
                    controller: capture,
                    onAccept: { newRoom in
                        cancelSearch()
                        activeRoom = newRoom
                        chairPose = GeometryKt.initialPlacement(room: newRoom, d: selectedProduct?.previewSize())
                        persistCurrentSession()
                        let quality = newRoom.scanQuality()
                        statusBanner = (quality == ScanQuality.complete) ? "Complete room scan accepted" : "Partial room scan accepted (boundary unverified)"
                        showScanSheet = false
                    },
                    onDismiss: {
                        showScanSheet = false
                    }
                )
            }
            .sheet(isPresented: $showConnections) {
                FreeConnectionsSheetView(credentials: credentials)
            }
            .sheet(isPresented: $showHelp) {
                HelpPrivacyView(
                    liveSearchConsent: liveSearchConsent,
                    onRevokeConsent: {
                        cancelSearch()
                        liveSearchConsent = false
                    },
                    onDelete: {
                        showHelp = false
                        showDeleteConfirmation = true
                    }
                )
            }
            .sheet(isPresented: $showAddChair) {
                AddChairSheetView { product in
                    cancelSearch()
                    sampleMode = false
                    products = Array((products.filter { $0.provenance != .fixture } + [product]).suffix(50))
                    selectedProduct = product
                    chairPose = GeometryKt.initialPlacement(room: activeRoom, d: product.previewSize())
                    statusBanner = "Chair added from your measurements. Verify assembled dimensions before buying."
                    persistCurrentSession()
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(url: url)
                }
            }
            .sheet(item: $editingProductForDims) { prod in
                EditDimensionsSheetView(product: prod) { updated in
                    if let idx = products.firstIndex(where: { $0.id == updated.id }) {
                        products[idx] = updated
                        if selectedProduct?.id == updated.id {
                            selectedProduct = updated
                        }
                        persistCurrentSession()
                    }
                }
            }
            .sheet(item: $detailsProduct) { prod in
                ProductDetailsSheetView(product: prod)
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    let scopedAccess = url.startAccessingSecurityScopedResource()
                    defer { if scopedAccess { url.stopAccessingSecurityScopedResource() } }
                    let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? Int.max
                    if size <= 5_000_000,
                       let text = try? String(contentsOf: url, encoding: .utf8),
                       let room = RoomPersistence.safeDecodeRoom(json: text) {
                        cancelSearch()
                        activeRoom = room
                        chairPose = GeometryKt.initialPlacement(room: room, d: selectedProduct?.previewSize())
                        persistCurrentSession()
                        statusBanner = "Imported room: \(room.name)"
                    } else {
                        statusBanner = "Import failed: file is not a valid RoomWise room. Previous room preserved."
                    }
                case .failure(let err):
                    statusBanner = "Import error: \(err.localizedDescription)"
                }
            }
            .alert("Allow live search?", isPresented: $showSearchConsent) {
                Button("Cancel", role: .cancel) {}
                Button("Allow & Search") {
                    liveSearchConsent = true
                    performSearch()
                }
            } message: {
                Text("Groq receives your chair request if a Groq key is configured. Tavily receives chair search requirements. Each key is sent only to its own provider for authentication. Use the providers’ free plans; limits apply. Room geometry and camera images are never sent to these providers. Revoke permission in Help & Privacy.")
            }
            .confirmationDialog("Delete saved rooms and searches?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete local data", role: .destructive) {
                    cancelSearch()
                    RoomPersistence.clearSavedData()
                    activeRoom = DemoKt.demoRoom()
                    products = DemoKt.demoProducts()
                    selectedProduct = products.first
                    chairPose = GeometryKt.initialPlacement(room: activeRoom, d: selectedProduct?.previewSize())
                    sampleMode = true
                    queryText = ""
                    searchLogs = []
                    retailerStatuses = Dictionary(uniqueKeysWithValues: ["Amazon UAE", "Noon UAE", "Temu"].map { ($0, "Sample fixture") })
                    liveSearchConsent = false
                    statusBanner = "Local data deleted. Provider keys can be cleared in Connections."
                }
            } message: {
                Text("Removes the saved room, products, placement, and search from this device. Files you exported and data already sent to providers are managed separately. Provider keys can be cleared in Connections.")
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    cancelSearch()
                    persistCurrentSession()
                    if case .scanning = capture.phase { capture.cancelScan() }
                    if case .processing = capture.phase { capture.cancelScan() }
                }
            }
        }
    }

    private func persistCurrentSession() {
        RoomPersistence.saveSession(
            room: activeRoom,
            query: queryText,
            products: products,
            selectedProductId: selectedProduct?.id,
            chairPose: chairPose,
            retailerStatuses: retailerStatuses,
            sampleMode: sampleMode
        )
    }

    // MARK: - Search Orchestration

    private func performSearch() {
        let query = String(queryText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(2000))
        guard !query.isEmpty else { return }
        guard sampleMode || liveSearchConsent else {
            showSearchConsent = true
            return
        }
        cancelSearch()
        let requestId = UUID()
        activeRequestId = requestId
        queryText = query
        isSearching = true
        searchLogs = []

        if sampleMode {
            let samples = DemoKt.demoProducts()
            products = products.filter { $0.provenance != .fixture } + samples
            selectedProduct = samples.first
            chairPose = GeometryKt.initialPlacement(room: activeRoom, d: selectedProduct?.previewSize())
            retailerStatuses = Dictionary(uniqueKeysWithValues: ["Amazon UAE", "Noon UAE", "Temu"].map { ($0, "Sample fixture") })
            statusBanner = "Offline sample chairs loaded"
            isSearching = false
            persistCurrentSession()
            return
        }
        guard credentials.hasTavilyKey else {
            isSearching = false
            statusBanner = "Add your free Tavily key in Connections, or use the retailer search links below."
            showConnections = true
            return
        }
        let tavilyKey = credentials.tavilyKey
        let groqKey = credentials.groqKey
        let model = credentials.groqModel
        products = products.filter { $0.provenance == .userEntered }
        selectedProduct = products.first
        retailerStatuses = Dictionary(uniqueKeysWithValues: ["Amazon UAE", "Noon UAE", "Temu"].map { ($0, "Waiting…") })
        statusBanner = "Preparing search…"
        searchTask = Task { @MainActor in
            do {
                let parsed = try await FreeShoppingParser.parse(prompt: query, groqKey: groqKey, model: model)
                guard activeRequestId == requestId else { return }
                searchLogs.append(parsed.engineLabel)
                searchLogs.append(parsed.note)
                let preferences = parsed.preferences
                searchLogs.append("Requirements: chair; colour \(preferences.colour ?? "any"); budget \(preferences.budget.map { "\(preferences.currency) \($0.doubleValue)" } ?? "not set"); features \(preferences.requiredFeatures.joined(separator: ", ")); maximum width \(preferences.maxWidth.map { "\($0.doubleValue) m" } ?? "not set"); maximum depth \(preferences.maxDepth.map { "\($0.doubleValue) m" } ?? "not set").")
                statusBanner = "Searching retailers · \(parsed.engineLabel)"
                try await FreeCatalogSearch().run(
                    preferences: parsed.preferences,
                    tavilyKey: tavilyKey,
                    onStoreUpdate: { store, found, status in
                        guard activeRequestId == requestId else { return }
                        retailerStatuses[store] = status
                        products = products.filter { $0.retailer != store || $0.provenance == .userEntered } + found
                        if selectedProduct == nil, let first = found.first {
                            selectedProduct = first
                            chairPose = GeometryKt.initialPlacement(room: activeRoom, d: first.previewSize())
                        }
                        persistCurrentSession()
                    },
                    onDiagnostic: { message in
                        guard activeRequestId == requestId else { return }
                        searchLogs.append(message)
                    }
                )
                guard activeRequestId == requestId else { return }
                let count = products.filter { $0.provenance == .live }.count
                statusBanner = count == 0 ? "No matching indexed listings. Try the retailer search links or add a chair yourself." : "\(count) listings from search evidence. Confirm offer and dimensions with the retailer."
            } catch is CancellationError {
                guard activeRequestId == requestId else { return }
                statusBanner = "Search cancelled"
            } catch {
                guard activeRequestId == requestId else { return }
                statusBanner = error.localizedDescription
                searchLogs.append(error.localizedDescription)
            }
            guard activeRequestId == requestId else { return }
            isSearching = false
            searchTask = nil
            persistCurrentSession()
        }
    }
    private func cancelSearch() {
        searchTask?.cancel()
        searchTask = nil
        persistCurrentSession()
        activeRequestId = UUID() // Immediately invalidate any in-flight callbacks
        isSearching = false
        statusBanner = "Search cancelled"
    }

    private func isLowestPrice(product: Product) -> Bool {
        guard let price = product.price?.doubleValue, price > 0, product.currency != nil else { return false }
        guard product.previewSize() != nil else { return false }
        let validPrices = products.compactMap { p -> Double? in
            guard p.previewSize() != nil, p.currency == product.currency,
                  let candidate = p.price?.doubleValue, candidate > 0 else { return nil }
            return candidate
        }
        guard let minPrice = validPrices.min() else { return false }
        return abs(price - minPrice) < 0.01
    }
}

struct HelpPrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    let liveSearchConsent: Bool
    let onRevokeConsent: () -> Void
    let onDelete: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Get started") {
                    Label("Scan on a LiDAR iPhone, or import a RoomWise JSON file from Room actions.", systemImage: "viewfinder")
                    Label("Select a chair and drag it in the room. Rotate or recenter it with the placement controls.", systemImage: "move.3d")
                    Label("Use Edit to enter assembled dimensions from a seller’s listing. Dimensions are width × depth × height.", systemImage: "ruler")
                    Label("AR shows a simplified chair at the entered dimensions, rather than the seller’s exact design.", systemImage: "arkit")
                }
                Section("Understanding fit") {
                    Text("Fit checks compare the chair’s floor footprint with captured walls and recognized furniture. A partial scan cannot confirm the room boundary. Always measure before buying: hidden obstacles, movement, overhead clearance, delivery routes, and door swings are not checked.")
                    Text("Sample rooms and sample chairs are synthetic examples. Live prices, availability, and dimensions can change; confirm them on the retailer’s site.")
                }
                Section("Privacy policy · November 1, 2026") {
                    Text("RoomWise saves your room geometry, search, products, and placement locally in app storage. The operating system may include this data in device backups. Camera images are used for RoomPlan and AR; RoomWise does not upload or save camera photos.")
                    Text("Sample mode, room scanning, dimension editing, and fit checks work without provider accounts. Automatic retailer search is optional and uses your own Tavily free-tier key. A Groq free-tier key enables a hosted LLM to interpret your request on any supported phone. Free plans have quotas; RoomWise does not upgrade accounts or switch to paid providers.")
                    Text("After your permission, Groq receives your chair request if configured. Tavily receives derived chair search requirements. Each key is sent only to its respective provider to authenticate requests. Neither provider receives room geometry, camera images, room counts, or placement data. Their policies apply to requests linked to your provider account.")
                    Text("Keys are stored in this device’s Keychain. They are sent only to their respective provider to authenticate requests. Keys are not included in room exports. RoomWise has no advertising, tracking, analytics SDK, or developer-operated account service.")
                    Text("Exported room files contain private geometry. Sharing a file is your choice; copies outside the app must be deleted separately. Retailer links open external websites with their own policies.")
                    Link("Groq privacy policy", destination: URL(string: "https://groq.com/privacy-policy/")!)
                    Link("Tavily privacy policy", destination: URL(string: "https://www.tavily.com/privacy")!)
                }
                Section("Your data") {
                    Text(liveSearchConsent ? "Live search sharing is allowed." : "Live search sharing is off. You will be asked before any live search.")
                    if liveSearchConsent {
                        Button("Revoke live search permission") { onRevokeConsent(); dismiss() }
                    }
                    Text("Clear provider keys in Connections. Deleting local data does not delete requests already handled by providers; use their account controls for that data.")
                    Button("Delete saved rooms & searches", role: .destructive, action: onDelete)
                }
                Section {
                    Link("Contact RoomWise support", destination: URL(string: "mailto:info.roomwise@gmail.com")!)
                    LabeledContent("Version", value: "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"))")
                }
            }
            .navigationTitle("Help & Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

// MARK: - Product Card View

struct ProductCardView: View {
    let product: Product
    let isSelected: Bool
    let isLowestPrice: Bool
    let onPreview: () -> Void
    let onEditDimensions: () -> Void
    let onDetails: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(product.retailer)
                    .font(.caption.bold())
                    .foregroundColor(forestGreen)
                Spacer()
                if isLowestPrice {
                    Text("Lowest price in these results")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(sageSurface)
                        .foregroundColor(forestGreen)
                        .clipShape(Capsule())
                }
                if product.provenance == ProductProvenance.fixture {
                    Text("Sample fixture")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                } else if product.provenance == .userEntered {
                    Text("User-entered")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(forestGreen)
                } else if product.provenance == ProductProvenance.savedLive {
                    Text("Saved live result")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(forestGreen)
                } else {
                    Text("Live result")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(forestGreen)
                }
            }

            Text(product.title)
                .font(.subheadline.bold())
                .foregroundColor(charcoalText)
                .lineLimit(2)

            HStack {
                if let price = product.price?.doubleValue, let curr = product.currency {
                    Text("\(curr) \(String(format: "%.2f", price))")
                        .font(.headline)
                        .foregroundColor(charcoalText)
                } else {
                    Text("Price unavailable")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let dims = product.previewSize() {
                    Text("\(Int(round(dims.width * 100))) × \(Int(round(dims.depth * 100))) × \(Int(round(dims.height * 100))) cm")
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                } else {
                    Text("Dimensions unavailable")
                        .font(.caption)
                        .foregroundColor(openingsAmber)
                }
            }

            // Plain-language feature badges
            if !product.features.isEmpty {
                HStack(spacing: 6) {
                    ForEach(product.features, id: \.name) { f in
                        let statusText = f.status == EvidenceStatus.supported ? "Listed" :
                                         f.status == EvidenceStatus.unsupported ? "Not listed" : "Not verified"
                        Text("\(f.name): \(statusText)")
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(sageSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }

            // Actions
            HStack(spacing: 8) {
                if product.previewSize() != nil {
                    Button("Preview in room") {
                        onPreview()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isSelected ? forestGreen : Color.secondary.opacity(0.15))
                    .foregroundColor(isSelected ? .white : forestGreen)
                    .controlSize(.small)
                } else {
                    Button("Add dimensions") {
                        onEditDimensions()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(forestGreen)
                    .controlSize(.small)
                }

                Button("Edit") {
                    onEditDimensions()
                }
                .buttonStyle(.bordered)
                .tint(forestGreen)
                .controlSize(.small)

                Button("Details") {
                    onDetails()
                }
                .buttonStyle(.bordered)
                .tint(forestGreen)
                .controlSize(.small)

                Spacer()

                if !product.url.isEmpty, let url = URL(string: product.url) {
                    if product.provenance == ProductProvenance.fixture {
                        Link("Retailer home · sample ↗", destination: url)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        let isAccepted: Bool = {
                            for r in [Retailer.amazon, Retailer.noon, Retailer.temu] {
                                if r.label == product.retailer && r.accepts(url: product.url) {
                                    return true
                                }
                            }
                            return false
                        }()
                        if isAccepted {
                            Link("Open product ↗", destination: url)
                                .font(.caption)
                                .foregroundColor(forestGreen)
                        } else {
                            Text("Listing URL unverified")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? forestGreen : sageBorder, lineWidth: isSelected ? 2 : 1)
        )
    }
}

// MARK: - Scan Sheet View

struct ScanSheetView: View {
    @ObservedObject var controller: RoomCaptureController
    let onAccept: (Room) -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                switch controller.phase {
                case .idle:
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "viewfinder")
                            .font(.system(size: 64))
                            .foregroundColor(forestGreen)
                        Text("Scan your room")
                            .font(.title3.bold())
                            .foregroundColor(forestGreen)
                        Text(RoomCaptureSession.isSupported ? "Capture all walls and furniture using LiDAR, then review the scan before using it. Keep the room well lit and move slowly." : "This iPhone does not support LiDAR room scanning. You can still import a room file, explore the sample room, and preview chair dimensions.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 32)

                        Button("Start scan") {
                            controller.startScan()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(forestGreen)
                        .controlSize(.large)
                        .disabled(!RoomCaptureSession.isSupported)
                        Spacer()
                    }

                case .scanning:
                    VStack(spacing: 12) {
                        CaptureViewRepresentable(controller: controller)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)

                        Text("Move slowly to scan all walls, openings, and furniture.")
                            .font(.footnote)
                            .foregroundColor(.secondary)

                        HStack(spacing: 16) {
                            Button("Cancel") {
                                controller.cancelScan()
                            }
                            .buttonStyle(.bordered)
                            .tint(openingsAmber)
                            .controlSize(.large)

                            Button("Finish scan") {
                                controller.finishScan()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(forestGreen)
                            .controlSize(.large)
                        }
                    }

                case .processing:
                    VStack(spacing: 16) {
                        Spacer()
                        ProgressView("Processing room geometry…")
                            .font(.headline)
                            .tint(forestGreen)
                        Text("Aligning walls and detected furniture…")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if controller.isProcessingLongerThanExpected {
                            VStack(spacing: 8) {
                                Text("Processing is taking longer than 15 seconds.")
                                    .font(.caption)
                                    .foregroundColor(openingsAmber)
                                Button("Cancel and keep previous room") {
                                    controller.cancelScan()
                                    onDismiss()
                                }
                                .buttonStyle(.bordered)
                                .tint(openingsAmber)
                                .controlSize(.small)
                            }
                            .padding(.top, 16)
                        }
                        Spacer()
                    }

                case .reviewing(let room):
                    let raw = (try? RoomExporter.data(room)) ?? Data()
                    let jsonStr = String(decoding: raw, as: UTF8.self)
                    let decodedRoom = RoomPersistence.safeDecodeRoom(json: jsonStr)
                    let quality = decodedRoom?.scanQuality() ?? ScanQuality.unusable

                    VStack(spacing: 14) {
                        Text("Review scan")
                            .font(.headline)
                            .foregroundColor(forestGreen)
                        Text("\(room.walls.count) walls · \(room.doors.count + room.windows.count + room.openings.count) openings · \(room.objects.count) objects")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        RoomReview(room: room)
                            .frame(height: 280)
                            .padding(.horizontal)

                        if quality == ScanQuality.complete {
                            Text("Complete scan · Boundary closed and placement-ready")
                                .font(.caption.bold())
                                .foregroundColor(forestGreen)
                        } else if quality == ScanQuality.partial {
                            Text("⚠️ Partial scan: Only \(room.walls.count) walls captured. Room boundary cannot be verified; furniture placement cannot confirm wall clearance.")
                                .font(.caption)
                                .foregroundColor(openingsAmber)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        } else {
                            Text("❌ Incomplete scan: No walls detected. Room cannot be used for placement.")
                                .font(.caption)
                                .foregroundColor(openingsAmber)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        VStack(spacing: 10) {
                            if quality == ScanQuality.complete {
                                Button("Accept scan") {
                                    if let decoded = decodedRoom {
                                        onAccept(decoded)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(forestGreen)
                                .controlSize(.large)
                            } else if quality == ScanQuality.partial {
                                Button("Use partial scan (boundary fit unverified)") {
                                    if let decoded = decodedRoom {
                                        onAccept(decoded)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(openingsAmber)
                                .controlSize(.large)
                            }

                            HStack(spacing: 16) {
                                Button("Scan again") {
                                    controller.startScan()
                                }
                                .foregroundColor(forestGreen)

                                Button("Discard") {
                                    controller.discardReview()
                                    onDismiss()
                                }
                                .foregroundColor(openingsAmber)
                            }
                        }
                        .padding(.horizontal)
                    }

                case .failed(let msg):
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(openingsAmber)
                        Text("Scan failed")
                            .font(.headline)
                        Text(msg)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button("Try again") {
                            controller.startScan()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(forestGreen)
                        if AVCaptureDevice.authorizationStatus(for: .video) == .denied,
                           let settings = URL(string: UIApplication.openSettingsURLString) {
                            Link("Open camera settings", destination: settings)
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle("LiDAR Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        if case .scanning = controller.phase {
                            controller.cancelScan()
                        } else if case .processing = controller.phase {
                            controller.cancelScan()
                        }
                        onDismiss()
                    }
                }
            }
            .onDisappear {
                if case .scanning = controller.phase {
                    controller.cancelScan()
                } else if case .processing = controller.phase {
                    controller.cancelScan()
                }
            }
        }
    }
}

// MARK: - Connections Sheet View

// MARK: - Edit Dimensions Sheet View

struct EditDimensionsSheetView: View {
    let product: Product
    let onSave: (Product) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var widthCm: String = ""
    @State private var depthCm: String = ""
    @State private var heightCm: String = ""

    private var validDimensions: Bool {
        [widthCm, depthCm, heightCm].allSatisfy {
            guard let value = Double($0.replacingOccurrences(of: ",", with: ".")) else { return false }
            return value.isFinite && value > 0 && value <= 1000
        }
    }

    init(product: Product, onSave: @escaping (Product) -> Void) {
        self.product = product
        self.onSave = onSave
        if let dims = product.previewSize() {
            _widthCm = State(initialValue: "\(Int(round(dims.width * 100)))")
            _depthCm = State(initialValue: "\(Int(round(dims.depth * 100)))")
            _heightCm = State(initialValue: "\(Int(round(dims.height * 100)))")
        } else {
            _widthCm = State(initialValue: "60")
            _depthCm = State(initialValue: "60")
            _heightCm = State(initialValue: "100")
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Assembled Dimensions (cm)"), footer: Text("Enter each assembled dimension between 0 and 1,000 cm. Check the seller’s listing, not the package size. Your measurements are labelled as user-entered.")) {
                    HStack {
                        Text("Width:")
                        TextField("cm", text: $widthCm)
                            .keyboardType(.decimalPad)
                    }
                    HStack {
                        Text("Depth:")
                        TextField("cm", text: $depthCm)
                            .keyboardType(.decimalPad)
                    }
                    HStack {
                        Text("Height:")
                        TextField("cm", text: $heightCm)
                            .keyboardType(.decimalPad)
                    }
                }
            }
            .navigationTitle("Add Dimensions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if validDimensions,
                           let w = Double(widthCm.replacingOccurrences(of: ",", with: ".")),
                           let d = Double(depthCm.replacingOccurrences(of: ",", with: ".")),
                           let h = Double(heightCm.replacingOccurrences(of: ",", with: ".")) {
                            let dims = Dimensions(width: w / 100.0, depth: d / 100.0, height: h / 100.0)
                            let evidence = SizeEvidence(
                                size: dims,
                                source: "User-entered dimensions: \(Int(w)) × \(Int(d)) × \(Int(h)) cm",
                                origin: "user",
                                kind: "assembled",
                                unit: "m"
                            )
                            let updated = product.doCopy(
                                id: product.id,
                                retailer: product.retailer,
                                title: product.title,
                                url: product.url,
                                imageUrl: product.imageUrl,
                                price: product.price,
                                currency: product.currency,
                                retrievedAt: product.retrievedAt,
                                variant: product.variant,
                                seller: product.seller,
                                dimensions: evidence,
                                features: product.features,
                                delivery: product.delivery,
                                availability: product.availability,
                                issues: product.issues,
                                source: product.source,
                                savedDemo: product.savedDemo,
                                provenance: product.provenance
                            )
                            onSave(updated)
                            dismiss()
                        }
                    }
                    .disabled(!validDimensions)
                }
            }
        }
    }
}

// MARK: - Product Details Sheet View

struct ProductDetailsSheetView: View {
    let product: Product
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Overview")) {
                    LabeledContent("Retailer", value: product.retailer)
                    LabeledContent("Title", value: product.title)
                    if let price = product.price?.doubleValue, let curr = product.currency {
                        LabeledContent("Price", value: "\(curr) \(String(format: "%.2f", price))")
                    } else {
                        LabeledContent("Price", value: "Price unavailable")
                    }
                    if let variant = product.variant {
                        LabeledContent("Variant / Model", value: variant)
                    }
                    if let seller = product.seller {
                        LabeledContent("Seller", value: seller)
                    }
                    LabeledContent("Retrieved", value: product.retrievedAt)
                }

                Section(header: Text("Dimensions & Evidence")) {
                    if let dims = product.dimensions {
                        LabeledContent("Origin", value: dims.origin)
                        LabeledContent("Kind", value: dims.kind)
                        LabeledContent("Source", value: dims.source)
                    } else {
                        Text("No assembled dimensions extracted from listing.")
                            .foregroundColor(.secondary)
                    }
                }

                if !product.features.isEmpty {
                    Section(header: Text("Feature Evidence")) {
                        ForEach(product.features, id: \.name) { f in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(f.name.capitalized)
                                        .font(.subheadline.bold())
                                    Spacer()
                                    Text(f.status == EvidenceStatus.supported ? "Listed" :
                                         f.status == EvidenceStatus.unsupported ? "Not listed" : "Not verified")
                                        .font(.caption)
                                        .foregroundColor(f.status == EvidenceStatus.supported ? forestGreen : openingsAmber)
                                }
                                if !f.source.isEmpty {
                                    Text(f.source)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                if !product.issues.isEmpty {
                    Section(header: Text("Notes & Uncertainty")) {
                        ForEach(product.issues, id: \.self) { issue in
                            Text("• \(issue)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Product Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Room Review Canvas

struct RoomReview: View {
    let room: CapturedRoom
    var body: some View {
        Canvas { context, size in
            let walls = room.walls
            let points = walls.flatMap { w -> [SIMD3<Float>] in
                let a = w.transform * SIMD4<Float>(-w.dimensions.x / 2, 0, 0, 1)
                let b = w.transform * SIMD4<Float>(w.dimensions.x / 2, 0, 0, 1)
                return [SIMD3(a.x, a.y, a.z), SIMD3(b.x, b.y, b.z)]
            }
            let minX = points.map(\.x).min() ?? -2, maxX = points.map(\.x).max() ?? 2
            let minZ = points.map(\.z).min() ?? -2, maxZ = points.map(\.z).max() ?? 2
            let scale = min((size.width - 24) / CGFloat(max(maxX - minX, 1)), (size.height - 24) / CGFloat(max(maxZ - minZ, 1)))
            func point(_ x: Float, _ z: Float) -> CGPoint {
                CGPoint(x: 12 + CGFloat(x - minX) * scale, y: 12 + CGFloat(z - minZ) * scale)
            }
            for i in stride(from: 0, to: points.count, by: 2) {
                var path = Path()
                path.move(to: point(points[i].x, points[i].z))
                path.addLine(to: point(points[i+1].x, points[i+1].z))
                context.stroke(path, with: .color(forestGreen), lineWidth: 3)
            }
            for o in room.objects {
                var path = Path()
                for (i, pair) in [(-1, -1), (1, -1), (1, 1), (-1, 1)].enumerated() {
                    let p = o.transform * SIMD4<Float>(Float(pair.0) * o.dimensions.x / 2, 0, Float(pair.1) * o.dimensions.z / 2, 1)
                    if i == 0 { path.move(to: point(p.x, p.z)) } else { path.addLine(to: point(p.x, p.z)) }
                }
                path.closeSubpath()
                context.fill(path, with: .color(forestGreen.opacity(0.22)))
            }
        }
        .background(sageSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
