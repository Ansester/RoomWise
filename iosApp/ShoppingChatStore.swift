import Foundation
import FitCheckShared

enum ShoppingChatStore {
    private static let messagesKey = "roomwise_conversation_messages_v1"
    private static let preferencesKey = "roomwise_conversation_preferences_v1"
    static func loadMessages() -> [ShoppingChatMessage] {
        guard let data = UserDefaults.standard.data(forKey: messagesKey), data.count <= 200_000,
              let messages = try? JSONDecoder().decode([ShoppingChatMessage].self, from: data) else { return [] }
        return Array(messages.filter { ["user", "assistant"].contains($0.role) && $0.content.count <= 2000 }.suffix(40))
    }
    static func loadPreferences() -> Preferences? {
        guard let data = UserDefaults.standard.data(forKey: preferencesKey),
              let requirements = try? JSONDecoder().decode(LocalChairRequirements.self, from: data) else { return nil }
        return try? FreeShoppingParser.validatedPreferences(requirements)
    }
    static func save(messages: [ShoppingChatMessage], preferences: Preferences) {
        if let data = try? JSONEncoder().encode(Array(messages.suffix(40))) { UserDefaults.standard.set(data, forKey: messagesKey) }
        let values: [String: Any] = [
            "budget": preferences.budget?.doubleValue as Any? ?? NSNull(), "currency": preferences.currency,
            "colour": preferences.colour as Any? ?? NSNull(), "requiredFeatures": preferences.requiredFeatures,
            "maxWidthMetres": preferences.maxWidth?.doubleValue as Any? ?? NSNull(),
            "maxDepthMetres": preferences.maxDepth?.doubleValue as Any? ?? NSNull()
        ]
        if let data = try? JSONSerialization.data(withJSONObject: values) { UserDefaults.standard.set(data, forKey: preferencesKey) }
    }
    static func clear() {
        UserDefaults.standard.removeObject(forKey: messagesKey)
        UserDefaults.standard.removeObject(forKey: preferencesKey)
    }
}
