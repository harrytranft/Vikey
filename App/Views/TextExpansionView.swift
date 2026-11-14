import SwiftUI

struct TextExpansionView: View {
    @AppStorage(PrefKey.useMacro) private var enabled = 1
    @AppStorage(PrefKey.macroInEnglish) private var inEnglish = 1
    @AppStorage(PrefKey.autoCapsMacro) private var autoCaps = 0

    @StateObject private var model = TextExpansionSettingsModel()
    @State private var editing: TextExpansionItem?
    @State private var creating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: flag($enabled)) {
                Tip("Bật gõ tắt", "Gõ một từ viết tắt rồi bấm Space, Enter, Tab hoặc dấu câu để thay bằng nội dung đã lưu.")
            }

            Toggle(isOn: flag($inEnglish)) {
                Tip("Gõ tắt trong chế độ tiếng Anh", "Cho phép dùng cùng danh sách gõ tắt khi Vikey đang ở English.")
            }
            .disabled(enabled == 0)

            Toggle(isOn: flag($autoCaps)) {
                Tip("Tự viết hoa", "Ví dụ với dc → được: Dc → Được và DC → ĐƯỢC.")
            }
            .disabled(enabled == 0)

            Divider()

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Tìm theo từ gõ tắt hoặc nội dung", text: $model.query)
                    .textFieldStyle(.plain)
                if !model.query.isEmpty {
                    Button { model.query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Xoá tìm kiếm")
                }
            }
            .padding(.horizontal, 9)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.055)))

            VStack(spacing: 0) {
                HStack {
                    Text("Từ gõ tắt").font(.caption).foregroundStyle(.secondary).frame(width: 120, alignment: .leading)
                    Text("Nội dung").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .frame(height: 28)

                Divider()

                if model.filtered.isEmpty {
                    VStack(spacing: 7) {
                        Image(systemName: model.query.isEmpty ? "text.badge.plus" : "magnifyingglass")
                            .font(.title2).foregroundStyle(.tertiary)
                        Text(model.query.isEmpty ? "Chưa có từ gõ tắt" : "Không tìm thấy")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 150)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(model.filtered) { item in
                                Button {
                                    editing = item
                                } label: {
                                    HStack(alignment: .top, spacing: 10) {
                                        Text(item.trigger)
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundStyle(.primary)
                                            .frame(width: 120, alignment: .leading)
                                            .lineLimit(1)
                                        Text(preview(item.replacement))
                                            .foregroundStyle(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .lineLimit(2)
                                        Image(systemName: "chevron.right")
                                            .font(.caption).foregroundStyle(.tertiary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                Divider().padding(.leading, 10)
                            }
                        }
                    }
                    .frame(height: 180)
                }
            }
            .background(RoundedRectangle(cornerRadius: 9).stroke(Color.primary.opacity(0.12)))

            HStack {
                Button {
                    creating = true
                } label: {
                    Label("Thêm", systemImage: "plus")
                }
                Button("Nhập…") { model.importOpenKey() }
                Button("Xuất…") { model.exportOpenKey() }
                    .disabled(model.entries.isEmpty)
                Spacer()
                Text(model.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .sheet(item: $editing) { item in
            TextExpansionEditor(
                title: "Sửa gõ tắt",
                initial: item,
                onSave: { updated in
                    if model.save(updated, replacing: item.id) { editing = nil }
                },
                onDelete: {
                    model.delete(item)
                    editing = nil
                },
                onCancel: { editing = nil }
            )
        }
        .sheet(isPresented: $creating) {
            TextExpansionEditor(
                title: "Thêm gõ tắt",
                initial: TextExpansionItem(trigger: "", replacement: ""),
                onSave: { item in
                    if model.save(item, replacing: nil) { creating = false }
                },
                onDelete: nil,
                onCancel: { creating = false }
            )
        }
        .alert("Vikey", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .onAppear { model.reload() }
    }

    private func preview(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: " ↵ ")
            .replacingOccurrences(of: "\n", with: " ↵ ")
            .replacingOccurrences(of: "\r", with: " ↵ ")
    }
}

private struct TextExpansionEditor: View {
    let title: String
    let initial: TextExpansionItem
    let onSave: (TextExpansionItem) -> Void
    let onDelete: (() -> Void)?
    let onCancel: () -> Void

    @State private var trigger: String
    @State private var replacement: String

    init(title: String, initial: TextExpansionItem,
         onSave: @escaping (TextExpansionItem) -> Void,
         onDelete: (() -> Void)?,
         onCancel: @escaping () -> Void) {
        self.title = title
        self.initial = initial
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
        _trigger = State(initialValue: initial.trigger)
        _replacement = State(initialValue: initial.replacement)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 5) {
                Text("Từ gõ tắt").font(.caption).foregroundStyle(.secondary)
                TextField("Ví dụ: dc", text: $trigger)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Nội dung thay thế").font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $replacement)
                    .font(.body)
                    .frame(height: 150)
                    .padding(5)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.16)))
            }

            Text("Replacement có thể chứa tiếng Việt, emoji và nhiều dòng.")
                .font(.caption).foregroundStyle(.secondary)

            HStack {
                if let onDelete {
                    Button("Xoá", role: .destructive, action: onDelete)
                }
                Spacer()
                Button("Huỷ", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Lưu") {
                    onSave(TextExpansionItem(id: initial.id, trigger: trigger, replacement: replacement))
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 430)
    }
}
