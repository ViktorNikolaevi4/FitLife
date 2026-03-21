// CloudStatusRow.swift
import SwiftUI
import CloudKit

struct CloudStatusRow: View {
    // поменяй на свой контейнер (как в Signing & Capabilities)
    private let containerID = "iCloud.Korolvoff.FitLife"
    @AppStorage(AppLanguage.appStorageKey) private var appLanguageRaw = AppLanguage.russian.rawValue

    @State private var status: CKAccountStatus? = nil
    @State private var checking = true

    private var appLanguage: AppLanguage {
        AppLanguage.from(rawValue: appLanguageRaw)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                if checking {
                    Text(appLanguage.localized("icloud.checking"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.primary.opacity(0.06))
        )
        .task { await refresh() }
        // обновлять при возвращении из бэкграунда
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await refresh() }
        }
    }

    // MARK: - Presentation

    private var title: String {
        guard let status else { return appLanguage.localized("icloud.title.checking") }
        switch status {
        case .available:                return appLanguage.localized("icloud.title.available")
        case .noAccount:                return appLanguage.localized("icloud.title.no_account")
        case .restricted:               return appLanguage.localized("icloud.title.restricted")
        case .temporarilyUnavailable:   return appLanguage.localized("icloud.title.temporarily_unavailable")
        case .couldNotDetermine:        fallthrough
        @unknown default:               return appLanguage.localized("icloud.title.unknown")
        }
    }

    private var subtitle: String? {
        guard let status else { return nil }
        switch status {
        case .available:
            return appLanguage.localized("icloud.subtitle.available")
        case .noAccount:
            return appLanguage.localized("icloud.subtitle.no_account")
        case .restricted:
            return appLanguage.localized("icloud.subtitle.restricted")
        case .temporarilyUnavailable:
            return appLanguage.localized("icloud.subtitle.unknown")
        case .couldNotDetermine:
            return appLanguage.localized("icloud.subtitle.unknown")
        @unknown default:
            return nil
        }
    }

    private var iconName: String {
        switch status {
        case .available?:               return "cloud.fill"
        case .temporarilyUnavailable?:  return "cloud.drizzle.fill"
        case .restricted?:              return "exclamationmark.triangle.fill"
        case .noAccount?:               return "icloud.slash"
        default:                        return "icloud"
        }
    }

    private var iconColor: Color {
        switch status {
        case .available?:               return .green
        case .temporarilyUnavailable?:  return .blue
        case .restricted?:              return .orange
        case .noAccount?:               return .red
        default:                        return .gray
        }
    }

    // MARK: - Check

    private func refresh() async {
        await MainActor.run { checking = true }
        do {
            let st = try await CKContainer(identifier: containerID).accountStatus()
            await MainActor.run {
                status = st
                checking = false
            }
        } catch {
            await MainActor.run {
                status = .couldNotDetermine
                checking = false
            }
        }
    }
}
