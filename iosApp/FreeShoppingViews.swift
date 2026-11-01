import SwiftUI
import FitCheckShared

enum RetailerCatalog {
    static func searchURL(store: Retailer, query: String) -> URL? {
        let text = String(query.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        guard !text.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = store == .amazon ? "www.amazon.ae" : store == .noon ? "www.noon.com" : "www.temu.com"
        components.path = store == .amazon ? "/s" : store == .noon ? "/uae-en/search/" : "/search_result.html"
        components.queryItems = [URLQueryItem(name: store == .amazon ? "k" : store == .noon ? "q" : "search_key", value: text)]
        return components.url
    }

    static func manualProduct(title: String, url: String, text: String, dimensions: Dimensions?) -> Product? {
        let name = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(300))
        let address = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, dimensions == nil || dimensions!.valid() else { return nil }
        let retailer = [Retailer.amazon, .noon, .temu].first { $0.accepts(url: address) }
        guard address.isEmpty || retailer != nil else { return nil }
        let source = String(text.prefix(6000))
        let listing = Listing(id: UUID().uuidString, retailer: retailer ?? .amazon, title: name, url: address, snippet: source, imageUrl: nil)
        let extracted = ProductExtractionKt.extractProduct(listing: listing, text: source, request: ProductExtractionKt.parseFixtureRequest(text: "chair"), retrievedAt: ISO8601DateFormatter().string(from: Date()))
        let size = dimensions.map { SizeEvidence(size: $0, source: "User-entered assembled dimensions", origin: "user", kind: "assembled", unit: "m") }
            ?? extracted.dimensions.map { SizeEvidence(size: $0.size, source: $0.source, origin: "user-pasted", kind: $0.kind, unit: $0.unit) }
        return extracted.doCopy(
            id: extracted.id, retailer: retailer?.label ?? "My measurements", title: name,
            url: address, imageUrl: nil, price: extracted.price, currency: extracted.currency,
            retrievedAt: extracted.retrievedAt, variant: extracted.variant, seller: extracted.seller,
            dimensions: size, features: extracted.features, delivery: nil, availability: nil,
            issues: ["Entered by you; retailer facts and dimensions have not been independently checked."],
            source: source, savedDemo: false, provenance: .userEntered
        )
    }
}

struct RetailerSearchLinksView: View {
    let query: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Browse retailer websites").font(.caption.bold())
            Text("These links send your query to the retailer when tapped. Add a listing or its assembled dimensions to your shortlist.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                ForEach([Retailer.amazon, .noon, .temu], id: \.name) { store in
                    if let url = RetailerCatalog.searchURL(store: store, query: query) {
                        Link(store.label, destination: url).font(.caption).buttonStyle(.bordered)
                    }
                }
            }
        }
    }
}

struct FreeConnectionsSheetView: View {
    @ObservedObject var credentials: SessionCredentials
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Free hosted LLM") {
                    Text("Groq interprets your chair request. It runs on Groq’s servers and works independently of your phone model. Stay on the Free plan; rate limits apply.")
                        .font(.caption).foregroundStyle(.secondary)
                    SecureField("Groq API key (optional)", text: $credentials.groqKey)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    LabeledContent("Groq model", value: FreeShoppingParser.defaultModel)
                    Text("Default: openai/gpt-oss-20b, hosted by Groq. Without a Groq key or on a model error, RoomWise uses its labelled offline parser.")
                        .font(.caption).foregroundStyle(.secondary)
                    Link("Get a free Groq key", destination: URL(string: "https://console.groq.com/keys")!)
                }
                Section("Free retailer search") {
                    SecureField("Tavily API key", text: $credentials.tavilyKey)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Text("Choose Tavily’s free Researcher plan with no payment method. One search uses up to three basic requests, one per retailer. RoomWise caps this installation at 300 requests per UTC month. Provider account limits may be reached sooner.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("\(FreeCatalogAllowance.shared.remainingRequests) local basic requests remain this month.")
                        .font(.caption)
                    Link("Tavily free plan & API keys", destination: URL(string: "https://www.tavily.com/pricing")!)
                }
                Section {
                    Button("Save keys securely") {
                        do { try credentials.saveFreeKeys(); message = "Keys saved in this device’s Keychain." }
                        catch { message = "Could not save keys. Try again." }
                    }
                    .disabled(!credentials.hasTavilyKey && !credentials.hasGroqKey)
                    Button("Clear saved provider keys", role: .destructive) {
                        do { try credentials.clear(); message = "All provider keys cleared." }
                        catch { message = "Could not clear keys. Try again." }
                    }
                    if !message.isEmpty { Text(message).font(.caption) }
                } footer: {
                    Text("Keys belong to you. Nothing is embedded in the repository or Release app. RoomWise never upgrades accounts or switches to a paid provider. Provider plans and limits are controlled by your account.")
                }
            }
            .navigationTitle("Connections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct AddChairSheetView: View {
    let onSave: (Product) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var url = ""
    @State private var listingText = ""
    @State private var width = ""
    @State private var depth = ""
    @State private var height = ""
    @State private var error = ""

    private var manualDimensions: Dimensions? {
        guard let w = Double(width.replacingOccurrences(of: ",", with: ".")),
              let d = Double(depth.replacingOccurrences(of: ",", with: ".")),
              let h = Double(height.replacingOccurrences(of: ",", with: ".")),
              [w, d, h].allSatisfy({ $0.isFinite && $0 > 0 && $0 <= 1000 }) else { return nil }
        return Dimensions(width: w / 100, depth: d / 100, height: h / 100)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Chair") {
                    TextField("Chair name", text: $title)
                    TextField("Full product URL (optional)", text: $url)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    Text("Use a full Amazon UAE, Noon UAE, or Temu product link, or leave it empty for your own chair.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    TextEditor(text: $listingText).frame(minHeight: 100)
                        .accessibilityLabel("Pasted listing details")
                } header: { Text("Paste listing details (optional)") } footer: {
                    Text("Pasted text is processed locally. Only unambiguous prices and labelled assembled dimensions are extracted. You can add measurements below.")
                }
                Section("Assembled dimensions · cm") {
                    LabeledContent("Width") { TextField("cm", text: $width).keyboardType(.decimalPad) }
                    LabeledContent("Depth") { TextField("cm", text: $depth).keyboardType(.decimalPad) }
                    LabeledContent("Height") { TextField("cm", text: $height).keyboardType(.decimalPad) }
                    Text("Enter all three dimensions, between 0 and 1,000 cm, or leave all blank. Package dimensions cannot confirm fit.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !error.isEmpty { Text(error).foregroundStyle(.red).font(.caption) }
            }
            .navigationTitle("Add your chair")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard [width, depth, height].allSatisfy({ $0.isEmpty }) || manualDimensions != nil else {
                            error = "Enter all three valid assembled dimensions, or leave all three blank."
                            return
                        }
                        guard let product = RetailerCatalog.manualProduct(title: title, url: url, text: listingText, dimensions: manualDimensions) else {
                            error = "Add a name and a valid full retailer product URL, or leave the URL empty."
                            return
                        }
                        onSave(product)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
