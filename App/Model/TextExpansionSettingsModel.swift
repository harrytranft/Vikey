import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

struct TextExpansionItem: Identifiable, Equatable {
    let id: UUID
    var trigger: String
    var replacement: String

    init(id: UUID = UUID(), trigger: String, replacement: String) {
        self.id = id
        self.trigger = trigger
        self.replacement = replacement
    }
}

@MainActor
final class TextExpansionSettingsModel: ObservableObject {
    @Published var entries: [TextExpansionItem] = []
    @Published var query = ""
    @Published var status = ""
    @Published var errorMessage: String?

    init() { reload() }

    var filtered: [TextExpansionItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return entries }
        return entries.filter {
            $0.trigger.localizedCaseInsensitiveContains(q) ||
            $0.replacement.localizedCaseInsensitiveContains(q)
        }
    }

    func reload() {
        entries = VikeyCore.textExpansions().compactMap { row in
            guard let trigger = row["trigger"], let replacement = row["replacement"] else { return nil }
            return TextExpansionItem(trigger: trigger, replacement: replacement)
        }
        status = "\(entries.count) mục gõ tắt"
    }

    @discardableResult
    func save(_ item: TextExpansionItem, replacing id: UUID?) -> Bool {
        let trigger = item.trigger
        let replacement = item.replacement
        guard !trigger.isEmpty else { errorMessage = "Từ gõ tắt không được để trống."; return false }
        guard !replacement.isEmpty else { errorMessage = "Nội dung thay thế không được để trống."; return false }
        guard trigger.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            errorMessage = "Từ gõ tắt không được chứa khoảng trắng hoặc xuống dòng."
            return false
        }

        var next = entries
        if next.contains(where: { $0.trigger == trigger && $0.id != id }) {
            errorMessage = "Từ gõ tắt này đã tồn tại. Hãy sửa mục hiện có hoặc chọn một từ khác."
            return false
        }
        if let id, let index = next.firstIndex(where: { $0.id == id }) {
            next[index] = TextExpansionItem(id: id, trigger: trigger, replacement: replacement)
        } else {
            next.append(TextExpansionItem(trigger: trigger, replacement: replacement))
        }

        guard persist(next) else { return false }
        status = "Đã lưu gõ tắt"
        return true
    }

    func delete(_ item: TextExpansionItem) {
        let next = entries.filter { $0.id != item.id }
        guard persist(next) else { return }
        status = "Đã xoá gõ tắt"
    }

    func importOpenKey() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Chọn tệp macro OpenKey/UniKey"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            let result = VikeyCore.importOpenKeyTextExpansions(text)
            guard (result["ok"] as? NSNumber)?.boolValue == true else {
                errorMessage = (result["error"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Tệp macro không hợp lệ."
                return
            }
            guard let imported = result["entries"] as? [[String: String]] else {
                errorMessage = "Không đọc được danh sách gõ tắt trong tệp."
                return
            }

            var next = entries
            var added = 0, replaced = 0
            for row in imported {
                guard let trigger = row["trigger"], let replacement = row["replacement"] else { continue }
                if let index = next.firstIndex(where: { $0.trigger == trigger }) {
                    next[index].replacement = replacement
                    replaced += 1
                } else {
                    next.append(TextExpansionItem(trigger: trigger, replacement: replacement))
                    added += 1
                }
            }
            guard persist(next) else { return }
            let skipped = (result["skipped"] as? NSNumber)?.intValue ?? 0
            var parts = ["Đã nhập \(added) mục mới"]
            if replaced > 0 { parts.append("cập nhật \(replaced) mục") }
            if skipped > 0 { parts.append("bỏ qua \(skipped) dòng") }
            status = parts.joined(separator: ", ")
        } catch {
            errorMessage = "Không đọc được tệp macro."
        }
    }

    func exportOpenKey() {
        let result = VikeyCore.exportOpenKeyTextExpansions()
        guard (result["ok"] as? NSNumber)?.boolValue == true,
              let text = result["text"] as? String else {
            errorMessage = (result["error"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Không xuất được danh sách gõ tắt."
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "Vikey-macro.txt"
        panel.message = "Xuất danh sách tương thích OpenKey/UniKey"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            let exported = (result["exported"] as? NSNumber)?.intValue ?? 0
            let skipped = (result["skipped"] as? NSNumber)?.intValue ?? 0
            status = skipped > 0
                ? "Đã xuất \(exported) mục, bỏ qua \(skipped) mục không tương thích định dạng cũ"
                : "Đã xuất \(exported) mục"
        } catch {
            errorMessage = "Không ghi được tệp macro."
        }
    }

    private func persist(_ next: [TextExpansionItem]) -> Bool {
        let payload = next.map { ["trigger": $0.trigger, "replacement": $0.replacement] }
        guard VikeyCore.saveTextExpansions(payload) else {
            errorMessage = "Không thể lưu danh sách gõ tắt."
            return false
        }
        entries = next
        Preferences.apply()
        return true
    }
}
