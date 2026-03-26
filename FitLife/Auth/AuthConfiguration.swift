import Foundation

enum AuthConfiguration {
    // Temporary bootstrap owner list until admin role management is moved server-side.
    static let ownerEmails: Set<String> = [
        "87v87@mail.ru"
    ]

    static func role(for email: String) -> AppUserRole {
        let normalizedEmail = email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return ownerEmails.contains(normalizedEmail) ? .owner : .client
    }
}
