import SwiftUI
import WebKit
import FitCheckShared

/// A page is tied to a known product identity. Swiping changes the shared selection.
struct ShoppingProductPager: View {
    let products: [Product]
    @Binding var selectedId: String?
    let onEdit: (Product) -> Void
    let onDetails: (Product) -> Void
    @State private var showRetailerPage = false
    @State private var pageChanged = false
    let onPageValidityChange: (Bool) -> Void

    private var index: Int { products.firstIndex { $0.id == selectedId } ?? 0 }
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button { move(-1) } label: { Image(systemName: "chevron.left") }
                    .disabled(products.isEmpty || index == 0).accessibilityLabel("Previous shopping page")
                Spacer()
                Text(products.isEmpty ? "No shopping pages" : "Page \(index + 1) of \(products.count) · swipe to compare")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button { move(1) } label: { Image(systemName: "chevron.right") }
                    .disabled(products.isEmpty || index >= products.count - 1).accessibilityLabel("Next shopping page")
            }
            if !products.isEmpty {
                TabView(selection: $selectedId) {
                    ForEach(products, id: \.id) { product in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                ProductCardView(product: product, isSelected: selectedId == product.id, isLowestPrice: false,
                                                onPreview: { selectedId = product.id }, onEditDimensions: { onEdit(product) }, onDetails: { onDetails(product) })
                                if product.provenance != .fixture,
                                   let url = URL(string: product.url), url.scheme == "https",
                                   [Retailer.amazon, .noon, .temu].contains(where: { $0.accepts(url: product.url) }) {
                                    Button(showRetailerPage ? "Close retailer page" : "Load retailer page") {
                                        showRetailerPage.toggle(); pageChanged = false; onPageValidityChange(true)
                                    }
                                    .buttonStyle(.bordered)
                                    Text("Loading connects directly to the retailer under its privacy policy. Preview uses saved listing dimensions: confirm the selected variant. Use the arrows to switch product pages.")
                                        .font(.caption2).foregroundStyle(.secondary)
                                    if showRetailerPage && selectedId == product.id {
                                        if pageChanged {
                                            Text("You followed a different retailer page. Preview paused: return to the selected listing or swipe to a known product.")
                                                .font(.caption).foregroundStyle(.orange)
                                        }
                                        RetailerWebPage(url: url) { current in
                                            let known = sameListingPage(current, url)
                                            pageChanged = !known
                                            onPageValidityChange(known)
                                        }
                                        .frame(height: 380).clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                            }.padding(.horizontal, 2)
                        }
                        .tag(Optional(product.id))
                    }
                }
                .accessibilityIdentifier("shopping-product-pages")
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: showRetailerPage ? 610 : 335)
                .onChange(of: selectedId) { _, _ in
                    pageChanged = false
                    onPageValidityChange(true)
                }
            }
        }
        .onDisappear { onPageValidityChange(true) }
    }
    private func move(_ offset: Int) {
        let next = index + offset
        guard products.indices.contains(next) else { return }
        withAnimation { selectedId = products[next].id }
    }
}

func sameListingPage(_ lhs: URL, _ rhs: URL) -> Bool {
    func identityQuery(_ url: URL) -> [String] {
        let tracking: Set<String> = ["tag", "ref", "ref_", "linkcode", "camp", "creative", "ascsubtag", "gclid", "fbclid"]
        return (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [])
            .filter { !tracking.contains($0.name.lowercased()) && !$0.name.lowercased().hasPrefix("utm_") }
            .map { "\($0.name)=\($0.value ?? "")" }.sorted()
    }
    return lhs.host?.lowercased().replacingOccurrences(of: "www.", with: "") == rhs.host?.lowercased().replacingOccurrences(of: "www.", with: "") &&
        lhs.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) == rhs.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) &&
        identityQuery(lhs) == identityQuery(rhs) && lhs.fragment == rhs.fragment
}

private struct RetailerWebPage: UIViewRepresentable {
    let url: URL
    let onNavigate: (URL) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onNavigate: onNavigate) }
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        context.coordinator.observation = view.observe(\.url, options: [.new]) { [weak coordinator = context.coordinator] _, change in
            if let url = change.newValue ?? nil { DispatchQueue.main.async { coordinator?.onNavigate(url) } }
        }
        view.load(URLRequest(url: url))
        context.coordinator.loadedURL = url
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.onNavigate = onNavigate
        if context.coordinator.loadedURL != url {
            context.coordinator.loadedURL = url
            view.load(URLRequest(url: url))
        }
    }
    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) { view.stopLoading(); view.navigationDelegate = nil; coordinator.observation?.invalidate(); coordinator.observation = nil }
    final class Coordinator: NSObject, WKNavigationDelegate {
        var observation: NSKeyValueObservation?
        var loadedURL: URL?
        var onNavigate: (URL) -> Void
        init(onNavigate: @escaping (URL) -> Void) { self.onNavigate = onNavigate }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url, url.scheme == "https" else { decisionHandler(.cancel); return }
            if navigationAction.targetFrame?.isMainFrame != false { onNavigate(url) }
            decisionHandler(.allow)
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let url = webView.url { onNavigate(url) }
        }
    }
}
