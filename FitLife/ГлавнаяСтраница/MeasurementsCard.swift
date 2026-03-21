import SwiftUI
import SwiftData

struct MeasurementsCard: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \BodyMeasurements.date, order: .reverse, animation: .snappy)
    private var items: [BodyMeasurements]

    // ввод
    @State private var isEditing = false
    @State private var date = Date()
    @State private var chestText = ""
    @State private var waistText = ""
    @State private var bellyText = ""
    @State private var hipsText  = ""

    private var last: BodyMeasurements? { items.first }

    var body: some View {
        SectionCard(title: AppLocalizer.string("measurements.title")) {
            HStack {
                if let last {
                    Label(last.date.formatted(date: .abbreviated, time: .omitted),
                          systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(AppLocalizer.string("measurements.empty")).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(isEditing ? AppLocalizer.string("common.cancel") : AppLocalizer.string("common.edit")) {
                    withAnimation(.easeInOut(duration: 0.2)) { toggleEdit() }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            }

            if isEditing {
                VStack(spacing: 10) {
                    DatePicker(AppLocalizer.string("common.date"), selection: $date, displayedComponents: .date)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)

                    fieldRow(AppLocalizer.string("measurements.chest"),  text: $chestText)
                    fieldRow(AppLocalizer.string("measurements.waist"), text: $waistText)
                    fieldRow(AppLocalizer.string("measurements.belly"), text: $bellyText)
                    fieldRow(AppLocalizer.string("measurements.hips"), text: $hipsText)

                    Button(AppLocalizer.string("common.save")) { save() }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .disabled(!isValid)
                }
            } else {
                VStack(spacing: 10) {
                    valueRow(AppLocalizer.string("measurements.chest"), last?.chest)
                    valueRow(AppLocalizer.string("measurements.waist"), last?.waist)
                    valueRow(AppLocalizer.string("measurements.belly"), last?.belly)
                    valueRow(AppLocalizer.string("measurements.hips"), last?.hips)
                }
            }
        }
        .onAppear { preloadFromLast() }
    }

    // MARK: UI helpers

    @ViewBuilder
    private func valueRow(_ title: String, _ value: Double?) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value.map { formatted($0) + " " + AppLocalizer.string("unit.cm") } ?? "—")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func fieldRow(_ title: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Text(title)
            Spacer()
            TextField(AppLocalizer.string("common.zero"), text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
                .textFieldStyle(.roundedBorder)
                .onChange(of: text.wrappedValue) {
                    text.wrappedValue = sanitize(text.wrappedValue)
                }
            Text(AppLocalizer.string("unit.cm")).foregroundStyle(.secondary)
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
        guard let last else { return }
        date = last.date
        chestText = formatted(last.chest)
        waistText = formatted(last.waist)
        bellyText = formatted(last.belly)
        hipsText  = formatted(last.hips)
    }

    private func toggleEdit() {
        if isEditing { preloadFromLast() } else if last == nil {
            date = .now; chestText = ""; waistText = ""; bellyText = ""; hipsText = ""
        }
        isEditing.toggle()
    }

    private func save() {
        guard
            let chest = Double(chestText.replacingOccurrences(of: ",", with: ".")),
            let waist = Double(waistText.replacingOccurrences(of: ",", with: ".")),
            let belly = Double(bellyText.replacingOccurrences(of: ",", with: ".")),
            let hips  = Double(hipsText .replacingOccurrences(of: ",", with: "."))
        else { return }

        let entry = BodyMeasurements(date: date, chest: chest, waist: waist, belly: belly, hips: hips)
        modelContext.insert(entry)
        do { try modelContext.save() } catch { print("Save measurements error:", error) }
        isEditing = false
    }
}
private struct SectionCard<Content: View>: View {
    let title: String?
    @ViewBuilder var content: Content
    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title; self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title { Text(title).font(.headline) }
            content
        }
        .padding(14)
        // если хочешь ВСЕГДА белый (даже в тёмной теме) — поставь .white
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))   // динамичный белый/чёрный
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.black.opacity(0.06))
        )
        .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 2)
        .padding(.horizontal)
    }
}
