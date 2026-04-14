import SwiftUI
import SwiftData

struct MeasurementsCard: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var sessionStore: AppSessionStore

    @Query(sort: \BodyMeasurements.date, order: .reverse, animation: .snappy)
    private var allItems: [BodyMeasurements]

    @State private var isEditing = false
    @State private var date = Date()
    @State private var chestText = ""
    @State private var waistText = ""
    @State private var bellyText = ""
    @State private var hipsText = ""

    private var currentOwnerId: String? { sessionStore.firebaseUser?.uid }
    private var items: [BodyMeasurements] {
        guard let currentOwnerId else { return [] }
        return allItems.filter { $0.ownerId == currentOwnerId }
    }
    private var last: BodyMeasurements? { items.first }

    private var latestValues: [(String, Double?)] {
        [
            (AppLocalizer.string("measurements.chest"), last?.chest),
            (AppLocalizer.string("measurements.waist"), last?.waist),
            (AppLocalizer.string("measurements.belly"), last?.belly),
            (AppLocalizer.string("measurements.hips"), last?.hips)
        ]
    }

    var body: some View {
        SectionCard(title: AppLocalizer.string("measurements.title")) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    if let last {
                        Label(last.date.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(AppLocalizer.string("measurements.latest"))
                            .font(.subheadline.weight(.medium))
                    } else {
                        Text(AppLocalizer.string("measurements.empty"))
                            .font(.subheadline.weight(.medium))

                        Text(AppLocalizer.string("measurements.empty.subtitle"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()

                Button(actionButtonTitle) {
                    withAnimation(.easeInOut(duration: 0.2)) { toggleEdit() }
                }
                .buttonStyle(.plain)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
            }

            if isEditing {
                VStack(spacing: 12) {
                    DatePicker(AppLocalizer.string("common.date"), selection: $date, displayedComponents: .date)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 2)

                    fieldRow(AppLocalizer.string("measurements.chest"), text: $chestText)
                    fieldRow(AppLocalizer.string("measurements.waist"), text: $waistText)
                    fieldRow(AppLocalizer.string("measurements.belly"), text: $bellyText)
                    fieldRow(AppLocalizer.string("measurements.hips"), text: $hipsText)

                    Button(AppLocalizer.string("common.save")) { save() }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .disabled(!isValid)
                }
            } else if last != nil {
                VStack(spacing: 10) {
                    ForEach(Array(latestValues.enumerated()), id: \.offset) { _, item in
                        valueRow(item.0, item.1)
                    }
                }
            } else {
                EmptyMeasurementsState {
                    withAnimation(.easeInOut(duration: 0.2)) { toggleEdit() }
                }
            }
        }
        .onAppear { preloadFromLast() }
    }

    @ViewBuilder
    private func valueRow(_ title: String, _ value: Double?) -> some View {
        HStack {
            Text(title)
                .font(.body.weight(.medium))
            Spacer()
            Text(value.map { formatted($0) + " " + AppLocalizer.string("unit.cm") } ?? AppLocalizer.string("measurements.not_set"))
                .font(.body.weight(.semibold))
                .foregroundStyle(value == nil ? .secondary : .primary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func fieldRow(_ title: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.body.weight(.medium))
            Spacer()
            TextField(AppLocalizer.string("common.zero"), text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 96)
                .textFieldStyle(.roundedBorder)
                .onChange(of: text.wrappedValue) {
                    text.wrappedValue = sanitize(text.wrappedValue)
                }
            Text(AppLocalizer.string("unit.cm"))
                .foregroundStyle(.secondary)
        }
    }

    private var isValid: Bool {
        [chestText, waistText, bellyText, hipsText]
            .allSatisfy { Double($0.replacingOccurrences(of: ",", with: ".")) != nil }
    }

    private func sanitize(_ s: String) -> String {
        let allowed = "0123456789,."
        var out = s.filter { allowed.contains($0) }
        if let i = out.firstIndex(of: ",") { out.replaceSubrange(i...i, with: ".") }
        out = out.replacingOccurrences(of: ",", with: "")
        let parts = out.split(separator: ".")
        return parts.count <= 1 ? out : parts[0] + "." + parts.dropFirst().joined()
    }

    private func formatted(_ v: Double) -> String {
        let s = String(format: "%.1f", v)
        return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
    }

    private func preloadFromLast() {
        guard let last else {
            date = .now
            chestText = ""
            waistText = ""
            bellyText = ""
            hipsText = ""
            return
        }
        date = last.date
        chestText = formatted(last.chest)
        waistText = formatted(last.waist)
        bellyText = formatted(last.belly)
        hipsText = formatted(last.hips)
    }

    private func toggleEdit() {
        if isEditing {
            preloadFromLast()
        } else if last == nil {
            date = .now
            chestText = ""
            waistText = ""
            bellyText = ""
            hipsText = ""
        }
        isEditing.toggle()
    }

    private func save() {
        guard
            let chest = Double(chestText.replacingOccurrences(of: ",", with: ".")),
            let waist = Double(waistText.replacingOccurrences(of: ",", with: ".")),
            let belly = Double(bellyText.replacingOccurrences(of: ",", with: ".")),
            let hips = Double(hipsText.replacingOccurrences(of: ",", with: "."))
        else { return }

        let entry = BodyMeasurements(ownerId: currentOwnerId ?? "", date: date, chest: chest, waist: waist, belly: belly, hips: hips)
        modelContext.insert(entry)
        do { try modelContext.save() } catch {}
        isEditing = false
    }

    private var actionButtonTitle: String {
        if isEditing {
            return AppLocalizer.string("common.cancel")
        }
        return last == nil ? AppLocalizer.string("common.add") : AppLocalizer.string("common.edit")
    }
}

private struct EmptyMeasurementsState: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppLocalizer.string("measurements.empty.body"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(AppLocalizer.string("measurements.add_button"), action: onAdd)
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 2)
    }
}

struct SectionCard<Content: View>: View {
    let title: String?
    @ViewBuilder var content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.headline.weight(.semibold))
            }
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.separator).opacity(0.22))
        )
        .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 2)
        .padding(.horizontal)
    }
}
