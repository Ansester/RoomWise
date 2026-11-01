import Foundation
import CryptoKit
import FitCheckShared

protocol HTTPTransport {
    func send(request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

final class URLSessionTransport: HTTPTransport {
    func send(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, http)
    }
}

struct RetailerStatus: Equatable {
    let storeName: String
    var statusText: String
    var products: [Product]
}

final class RetailerService {
    private let transport: HTTPTransport
    var onDiagnostic: ((String) -> Void)? = nil

    init(transport: HTTPTransport = URLSessionTransport()) {
        self.transport = transport
    }

    /// Case-insensitive chair matching across English and Arabic terms.
    static func isChairMatch(title: String, content: String) -> Bool {
        let combined = title + " " + content
        guard combined.range(of: "chair|كرسي", options: [.regularExpression, .caseInsensitive]) != nil else {
            return false
        }

        // Search engines commonly rank chair accessories above complete chairs. Do not let
        // two accessory hits consume the small, verified-product candidate set.
        let accessoryOnlyTitle = "chair\\s+(?:armrest\\s+)?(?:covers?|slipcovers?|wheels?|casters?|mats?|pads?|cushions?|parts?|accessor(?:y|ies))|armrests?\\s+(?:replacement|pads?|covers?|slipcovers?)|(?:replacement|pads?|covers?|slipcovers?)\\s+armrests?|replacement\\s+(?:wheels?|casters?)|chair\\s+gas\\s+(?:lift|cylinder)"
        return title.range(of: accessoryOnlyTitle, options: [.regularExpression, .caseInsensitive]) == nil
    }

    func search(
        store: Retailer,
        request: Preferences,
        tavilyKey: String,
        onDiagnostic: ((String) -> Void)? = nil
    ) async throws -> [Listing] {
        let diag = onDiagnostic ?? self.onDiagnostic
        guard !Task.isCancelled else { throw CancellationError() }
        let trimmedKey = tavilyKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw NSError(domain: "RoomWise", code: 401, userInfo: [NSLocalizedDescriptionKey: "Tavily API key required for live retailer search."])
        }

        // Tavily's include_domains is only a preference in some result sets, so put the
        // domain constraint in the query as well. Avoid leading with "under": that word
        // can dominate semantic results and return dictionary pages rather than products.
        let queryParts = [
            "site:\(store.domain)",
            store.label,
            request.colour,
            request.category,
            request.requiredFeatures.joined(separator: " "),
            request.budget != nil ? "\(request.currency) \(request.budget!.doubleValue) maximum" : nil,
            "UAE product listing"
        ].compactMap { $0 }
        let query = String(queryParts.joined(separator: " ").prefix(500))

        let searchBody: [String: Any] = [
            "query": query,
            "max_results": 10,
            "search_depth": "basic",
            "auto_parameters": false,
            "topic": "general",
            "include_answer": false,
            "include_raw_content": false,
            "include_images": true,
            "include_domains": [store.domain]
        ]

        var searchReq = URLRequest(url: URL(string: "https://api.tavily.com/search")!)
        searchReq.httpMethod = "POST"
        searchReq.addValue("application/json", forHTTPHeaderField: "Content-Type")
        searchReq.addValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        searchReq.httpBody = try JSONSerialization.data(withJSONObject: searchBody)
        searchReq.timeoutInterval = 25.0

        let (searchData, searchResp) = try await transport.send(request: searchReq)
        try Task.checkCancellation()
        guard (200...299).contains(searchResp.statusCode) else {
            diag?("\(store.label): Tavily search returned HTTP \(searchResp.statusCode)")
            throw NSError(domain: "RoomWise", code: searchResp.statusCode, userInfo: [NSLocalizedDescriptionKey: "Tavily search HTTP \(searchResp.statusCode)"])
        }

        guard let searchJson = try JSONSerialization.jsonObject(with: searchData) as? [String: Any],
              let results = searchJson["results"] as? [[String: Any]] else {
            diag?("\(store.label): Tavily search returned unparseable JSON")
            return []
        }

        if results.isEmpty {
            diag?("\(store.label): Tavily search returned 0 candidates")
            return []
        }

        var candidateListings: [Listing] = []
        for item in results {
            guard let url = item["url"] as? String else { continue }
            guard store.accepts(url: url) else {
                diag?("\(store.label): URL rejected (not a valid product page): \(url)")
                continue
            }
            guard let title = item["title"] as? String, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                diag?("\(store.label): Candidate skipped (missing title)")
                continue
            }
            let content = (item["content"] as? String) ?? ""
            guard Self.isChairMatch(title: title, content: content) else {
                diag?("\(store.label): Candidate skipped (not a chair match): \"\(title.prefix(60))\"")
                continue
            }

            var imageUrl: String? = nil
            if let images = item["images"] as? [Any], let first = images.first {
                if let str = first as? String, str.hasPrefix("https://") { imageUrl = str }
                else if let dict = first as? [String: Any], let str = dict["url"] as? String, str.hasPrefix("https://") { imageUrl = str }
            }

            let listing = Listing(
                // Swift's hashValue changes across launches and abs(Int.min) traps.
                // A stable identifier keeps saved selections tied to the same listing.
                id: "\(store.name)-\(SHA256.hash(data: Data(url.utf8)).prefix(12).map { String(format: "%02x", $0) }.joined())",
                retailer: store,
                title: String(title.prefix(300)),
                url: url,
                snippet: String(content.prefix(6000)),
                imageUrl: imageUrl
            )
            if !candidateListings.contains(where: { $0.url == listing.url }) {
                candidateListings.append(listing)
            }
            if candidateListings.count >= 2 { break }
        }

        diag?("\(store.label): \(candidateListings.count) verified product candidates found")
        return candidateListings
    }

    /// Produces a deliberately incomplete LIVE card from a validated Tavily search result.
    /// This preserves the usable product link when a retailer blocks full-page extraction;
    /// the shared conservative parser leaves unobserved price/dimensions/features unknown.
    static func productFromSearchEvidence(listing: Listing, request: Preferences) -> Product? {
        guard listing.retailer.accepts(url: listing.url),
              !listing.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              isChairMatch(title: listing.title, content: listing.snippet) else {
            return nil
        }

        var evidence = "Tavily search result title: \(listing.title)"
        let snippet = listing.snippet.trimmingCharacters(in: .whitespacesAndNewlines)
        if !snippet.isEmpty {
            evidence += "\nTavily search result snippet: \(snippet)"
        }

        let product = ProductExtractionKt.extractProduct(
            listing: listing,
            text: evidence,
            request: request,
            retrievedAt: ISO8601DateFormatter().string(from: Date())
        )
        let evidenceIssue = "Full retailer page was not verified; this card uses Tavily search-result evidence only. Verify price, dimensions, variant, and availability on the retailer page."
        return liveProduct(product, additionalIssues: [evidenceIssue])
    }

    private static func liveProduct(_ product: Product, additionalIssues: [String] = []) -> Product {
        product.doCopy(
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
            dimensions: product.dimensions,
            features: product.features,
            delivery: product.delivery,
            availability: product.availability,
            issues: product.issues + additionalIssues,
            source: product.source,
            savedDemo: false,
            provenance: ProductProvenance.live
        )
    }

    func extract(
        listing: Listing,
        request: Preferences,
        tavilyKey: String,
        onDiagnostic: ((String) -> Void)? = nil
    ) async throws -> Product? {
        let diag = onDiagnostic ?? self.onDiagnostic
        guard !Task.isCancelled else { throw CancellationError() }
        let trimmedKey = tavilyKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw NSError(domain: "RoomWise", code: 401, userInfo: [NSLocalizedDescriptionKey: "Tavily API key required for live retailer search."])
        }
        guard listing.retailer.accepts(url: listing.url) else {
            throw NSError(domain: "RoomWise", code: 400, userInfo: [NSLocalizedDescriptionKey: "The listing is not a supported retailer product page."])
        }

        let extractBody: [String: Any] = [
            "urls": [listing.url],
            "extract_depth": "basic",
            "format": "text"
        ]
        var extractReq = URLRequest(url: URL(string: "https://api.tavily.com/extract")!)
        extractReq.httpMethod = "POST"
        extractReq.addValue("application/json", forHTTPHeaderField: "Content-Type")
        extractReq.addValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        extractReq.httpBody = try JSONSerialization.data(withJSONObject: extractBody)
        extractReq.timeoutInterval = 25.0

        do {
            let (extData, extResp) = try await transport.send(request: extractReq)
            try Task.checkCancellation()
            guard (200...299).contains(extResp.statusCode) else {
                diag?("\(listing.retailer.label): Tavily extract returned HTTP \(extResp.statusCode); retaining validated search-result evidence")
                return Self.productFromSearchEvidence(listing: listing, request: request)
            }

            guard let extJson = try JSONSerialization.jsonObject(with: extData) as? [String: Any],
                  let extResults = extJson["results"] as? [[String: Any]],
                  let matchingResult = extResults.first(where: { ($0["url"] as? String) == listing.url }),
                  let rawText = matchingResult["raw_content"] as? String,
                  !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                diag?("\(listing.retailer.label): Tavily extract returned empty content; retaining validated search-result evidence")
                return Self.productFromSearchEvidence(listing: listing, request: request)
            }

            let product = ProductExtractionKt.extractProduct(
                listing: listing,
                text: rawText,
                request: request,
                retrievedAt: ISO8601DateFormatter().string(from: Date())
            )
            let liveProduct = Self.liveProduct(product)

            if liveProduct.previewSize() == nil {
                diag?("\(listing.retailer.label): Extracted product has missing/unverified dimensions: \"\(liveProduct.title.prefix(50))\"")
            } else {
                diag?("\(listing.retailer.label): Extracted product with verified dimensions: \"\(liveProduct.title.prefix(50))\"")
            }

            return liveProduct
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // URLSession reports cancellation as URLError.cancelled rather than
            // CancellationError. A cancelled search must never synthesize a late card.
            try Task.checkCancellation()
            if (error as? URLError)?.code == .cancelled { throw CancellationError() }
            diag?("\(listing.retailer.label): Tavily extract failed (\(error.localizedDescription)); retaining validated search-result evidence")
            return Self.productFromSearchEvidence(listing: listing, request: request)
        }
    }

    func searchAndExtract(
        store: Retailer,
        request: Preferences,
        tavilyKey: String,
        onDiagnostic: ((String) -> Void)? = nil
    ) async throws -> [Product] {
        guard !Task.isCancelled else { throw CancellationError() }
        let listings = try await search(store: store, request: request, tavilyKey: tavilyKey, onDiagnostic: onDiagnostic)
        guard !listings.isEmpty else { return [] }

        var products: [Product] = []
        for listing in listings {
            guard !Task.isCancelled else { throw CancellationError() }
            do {
                if let product = try await extract(listing: listing, request: request, tavilyKey: tavilyKey, onDiagnostic: onDiagnostic) {
                    products.append(product)
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                onDiagnostic?("\(store.label): Extraction failed for \(listing.url): \(error.localizedDescription)")
            }
        }
        return products
    }
}
