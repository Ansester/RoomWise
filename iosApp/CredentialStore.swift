import Foundation
import Security

public protocol CredentialStore {
    func loadOpenAIKey() -> String?
    func loadTavilyKey() -> String?
    func loadGroqKey() -> String?
    func saveOpenAIKey(_ value: String) throws
    func saveTavilyKey(_ value: String) throws
    func saveGroqKey(_ value: String) throws
    func clear() throws
}

public final class KeychainCredentialStore: CredentialStore {
    private let service: String
    private let openAIAccount = "openai-api-key"
    private let tavilyAccount = "tavily-api-key"
    private let groqAccount = "groq-api-key"

    public init(service: String = "dev.fitcheck.prototype.credentials") {
        self.service = service
    }

    public func loadOpenAIKey() -> String? {
        load(account: openAIAccount)
    }

    public func loadTavilyKey() -> String? {
        load(account: tavilyAccount)
    }

    public func loadGroqKey() -> String? {
        load(account: groqAccount)
    }

    public func saveOpenAIKey(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            try delete(account: openAIAccount)
        } else {
            try save(account: openAIAccount, value: trimmed)
        }
    }

    public func saveTavilyKey(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            try delete(account: tavilyAccount)
        } else {
            try save(account: tavilyAccount, value: trimmed)
        }
    }

    public func clear() throws {
        try delete(account: openAIAccount)
        try delete(account: tavilyAccount)
        try delete(account: groqAccount)
    }

    public func saveGroqKey(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { try delete(account: groqAccount) }
        else { try save(account: groqAccount, value: trimmed) }
    }

    private func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func save(account: String, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw NSError(domain: "RoomWise.Keychain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode credential"])
        }

        let checkQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        #if os(macOS)
        let accessible = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        #else
        let accessible = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        #endif

        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessible
        ]

        let status = SecItemUpdate(checkQuery as CFDictionary, updateAttributes as CFDictionary)
        if status == errSecItemNotFound {
            var newQuery = checkQuery
            newQuery[kSecValueData as String] = data
            newQuery[kSecAttrAccessible as String] = accessible
            let addStatus = SecItemAdd(newQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw NSError(domain: "RoomWise.Keychain", code: Int(addStatus), userInfo: [NSLocalizedDescriptionKey: "Keychain write error (code \(addStatus))"])
            }
        } else if status != errSecSuccess {
            throw NSError(domain: "RoomWise.Keychain", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Keychain update error (code \(status))"])
        }
    }

    private func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw NSError(domain: "RoomWise.Keychain", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Keychain delete error (code \(status))"])
        }
    }
}

public final class InMemoryCredentialStore: CredentialStore {
    private var storage: [String: String] = [:]
    public var shouldThrowOnSave: Bool = false

    public init(initialOpenAIKey: String? = nil, initialTavilyKey: String? = nil, initialGroqKey: String? = nil) {
        if let k = initialOpenAIKey { storage["openai-api-key"] = k }
        if let k = initialTavilyKey { storage["tavily-api-key"] = k }
        if let k = initialGroqKey { storage["groq-api-key"] = k }
    }

    public func loadOpenAIKey() -> String? {
        storage["openai-api-key"]
    }

    public func loadTavilyKey() -> String? {
        storage["tavily-api-key"]
    }

    public func loadGroqKey() -> String? {
        storage["groq-api-key"]
    }

    public func saveOpenAIKey(_ value: String) throws {
        if shouldThrowOnSave {
            throw NSError(domain: "RoomWise.CredentialStore", code: -99, userInfo: [NSLocalizedDescriptionKey: "Simulated credential store error"])
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            storage.removeValue(forKey: "openai-api-key")
        } else {
            storage["openai-api-key"] = trimmed
        }
    }

    public func saveTavilyKey(_ value: String) throws {
        if shouldThrowOnSave {
            throw NSError(domain: "RoomWise.CredentialStore", code: -99, userInfo: [NSLocalizedDescriptionKey: "Simulated credential store error"])
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            storage.removeValue(forKey: "tavily-api-key")
        } else {
            storage["tavily-api-key"] = trimmed
        }
    }

    public func clear() throws {
        storage.removeAll()
    }

    public func saveGroqKey(_ value: String) throws {
        if shouldThrowOnSave {
            throw NSError(domain: "RoomWise.CredentialStore", code: -99, userInfo: [NSLocalizedDescriptionKey: "Simulated credential store error"])
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { storage.removeValue(forKey: "groq-api-key") }
        else { storage["groq-api-key"] = trimmed }
    }
}
