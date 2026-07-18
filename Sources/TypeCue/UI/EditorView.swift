import AppKit
import SwiftUI

/// Shared height of the bottom control bars (scripts +/- and Add Block) so their
/// dividers align across the split view.
private let footerBarHeight: CGFloat = 30

/// Script editor: scripts list on the left, ordered blocks of the selected script on the
/// right. Changes apply immediately (autosaved via the store). Speed and pauses are
/// authored inline with markers (see the Formatting popover), so each block is a plain
/// text field. Embedded as the "Scripts" tab of `MainWindowView`.
struct ScriptsEditorView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @State private var selectedID: UUID?
    @State private var showFormatting = false

    var body: some View {
        VStack(spacing: 0) {
            actionBar
            Divider()
            if let error = coordinator.store.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.red.opacity(0.08))
            }
            NavigationSplitView {
                scriptsList
                    .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
            } detail: {
                detail
                    .frame(minWidth: 440)
            }
            .navigationSplitViewStyle(.balanced)
        }
        .frame(minWidth: 700, minHeight: 460)
        .onAppear {
            // Prefer the active script (e.g. one just created via "New Script" from the
            // menu) so the editor opens directly at it, even if this window instance was
            // already open and is just being brought back to front.
            selectedID = coordinator.session.activeScriptID ?? coordinator.store.scripts.first?.id
        }
        .onChange(of: coordinator.session.activeScriptID) { _, newValue in
            if let newValue { selectedID = newValue }
        }
    }

    // MARK: - Action bar

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button(action: newScript) {
                Label("New Script", systemImage: "square.and.pencil")
            }
            Button(action: addSample) {
                Label("Add Sample", systemImage: "sparkles")
            }

            Spacer()

            Menu {
                Button(action: { coordinator.importScript() }) {
                    Label("Import\u{2026}", systemImage: "square.and.arrow.down")
                }
                Button(action: exportSelected) {
                    Label("Export\u{2026}", systemImage: "square.and.arrow.up")
                }
                .disabled(selectedID == nil)
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()

            Button(action: { showFormatting.toggle() }) {
                Label("Formatting", systemImage: "questionmark.circle")
            }
            .popover(isPresented: $showFormatting, arrowEdge: .bottom) {
                FormattingHelp()
            }
        }
        .labelStyle(.titleAndIcon)
        .buttonStyle(.borderless)
        .padding(10)
    }

    // MARK: - Scripts list

    private var scriptsList: some View {
        List(selection: $selectedID) {
            ForEach(coordinator.store.scripts) { script in
                Text(script.name.isEmpty ? "Untitled" : script.name)
                    .tag(script.id)
                    .contextMenu { scriptMenu(for: script) }
            }
            .onMove { indices, destination in
                coordinator.store.moveScript(fromOffsets: indices, toOffset: destination)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            listFooter
        }
    }

    @ViewBuilder
    private func scriptMenu(for script: Script) -> some View {
        Button("Make Active") { coordinator.setActiveScript(script.id) }
            .disabled(coordinator.session.activeScriptID == script.id)
        Button("Duplicate") { duplicate(script) }
        Button("Export\u{2026}") { coordinator.exportScript(script) }
        Divider()
        Button("Delete", role: .destructive) { delete(script) }
    }

    private func duplicate(_ script: Script) {
        // Fresh ids throughout so the copy never collides with the original.
        let copy = Script(
            name: script.name.isEmpty ? "Untitled copy" : "\(script.name) copy",
            blocks: script.blocks.map { TextBlock(text: $0.text) }
        )
        coordinator.store.addScript(copy)
        selectedID = copy.id
    }

    private func delete(_ script: Script) {
        coordinator.store.deleteScript(id: script.id)
        if coordinator.session.activeScriptID == script.id {
            coordinator.setActiveScript(nil)
        }
        if selectedID == script.id {
            selectedID = coordinator.store.scripts.first?.id
        }
    }

    /// Native list-footer control bar (matching System Settings): a divider above small,
    /// borderless +/- buttons, inset from the window edge.
    private var listFooter: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 2) {
                Button(action: addScript) {
                    Image(systemName: "plus")
                        .frame(width: 20, height: 20)
                }
                .accessibilityIdentifier("addScriptButton")
                .accessibilityLabel("New script")
                .help("New script")
                Button(action: deleteSelectedScript) {
                    Image(systemName: "minus")
                        .frame(width: 20, height: 20)
                }
                .disabled(selectedID == nil)
                .accessibilityLabel("Delete script")
                .help("Delete script")
                Spacer()
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .padding(.horizontal, 8)
            .frame(height: footerBarHeight)
        }
        // Opaque bar so scrolled list content doesn't show through the inset footer.
        .background(.bar)
    }

    // MARK: - Detail

    /// A live binding straight into the store for the selected script, or `nil` if
    /// nothing is selected. Deliberately NOT built via `Binding($optionalState)` - that
    /// pattern force-unwraps internally and crashes if the optional flips to `nil` (e.g.
    /// selection cleared by clicking empty list space) while SwiftUI is mid-update with a
    /// view still holding the old binding. This version's `get` always has a safe
    /// fallback, so it can never crash even if the id vanishes from the store concurrently
    /// (e.g. deleted elsewhere) - it just returns the last known snapshot.
    private func scriptBinding(for id: UUID) -> Binding<Script>? {
        guard let initial = coordinator.store.scripts.first(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { coordinator.store.scripts.first(where: { $0.id == id }) ?? initial },
            set: { coordinator.store.updateScript($0) }
        )
    }

    @ViewBuilder
    private var detail: some View {
        if let id = selectedID, let binding = scriptBinding(for: id) {
            ScriptDetailView(script: binding)
        } else {
            ContentUnavailableView {
                Label("No script selected", systemImage: "text.cursor")
            } description: {
                Text("Create one with New Script, or pick one on the left.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Actions

    private func addScript() {
        let new = Script(name: "Untitled script", blocks: [TextBlock(text: "")])
        coordinator.store.addScript(new)
        selectedID = new.id
    }

    private func newScript() {
        addScript()
    }

    private func addSample() {
        coordinator.addSampleScript()
        selectedID = coordinator.session.activeScriptID
    }

    private func exportSelected() {
        guard let id = selectedID,
              let script = coordinator.store.scripts.first(where: { $0.id == id }) else { return }
        coordinator.exportScript(script)
    }

    private func deleteSelectedScript() {
        guard let id = selectedID else { return }
        coordinator.store.deleteScript(id: id)
        if coordinator.session.activeScriptID == id {
            coordinator.setActiveScript(nil)
        }
        selectedID = coordinator.store.scripts.first?.id
    }
}

private struct ScriptDetailView: View {
    @Binding var script: Script

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Script name", text: $script.name)
                    .textFieldStyle(.roundedBorder)
                    .font(.headline)
                    .accessibilityIdentifier("scriptNameField")

                Text("Each block is typed on one hotkey press, in order. Reorder by dragging the handle or from a block's menu. Add pauses and speed changes with markers - see Formatting above.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)

            Divider()

            List {
                ForEach(script.blocks.indices, id: \.self) { offset in
                    BlockRow(
                        block: $script.blocks[offset],
                        index: offset + 1,
                        isFirst: offset == 0,
                        isLast: offset == script.blocks.count - 1,
                        moveUp: { move(from: offset, to: offset - 1) },
                        moveDown: { move(from: offset, to: offset + 1) },
                        delete: { delete(at: offset) }
                    )
                }
                .onMove { indices, destination in
                    script.blocks.move(fromOffsets: indices, toOffset: destination)
                }
            }
            .listStyle(.inset)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    Divider()
                    HStack {
                        Button {
                            script.blocks.append(TextBlock(text: ""))
                        } label: {
                            Label("Add Block", systemImage: "plus")
                        }
                        .accessibilityIdentifier("addBlockButton")
                        Spacer()
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .padding(.horizontal, 12)
                    .frame(height: footerBarHeight)
                }
                .background(.bar)
            }
        }
    }

    private func move(from source: Int, to destination: Int) {
        guard script.blocks.indices.contains(source),
              script.blocks.indices.contains(destination) else { return }
        script.blocks.swapAt(source, destination)
    }

    private func delete(at index: Int) {
        guard script.blocks.indices.contains(index) else { return }
        script.blocks.remove(at: index)
    }
}

private struct BlockRow: View {
    @Binding var block: TextBlock
    let index: Int
    let isFirst: Bool
    let isLast: Bool
    let moveUp: () -> Void
    let moveDown: () -> Void
    let delete: () -> Void

    @ScaledMetric private var editorMinHeight: CGFloat = 60

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.tertiary)
                    .help("Drag to reorder")
                    .accessibilityHidden(true)
                Text("Block \(index)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Button(action: moveUp) { Label("Move Up", systemImage: "arrow.up") }
                        .disabled(isFirst)
                    Button(action: moveDown) { Label("Move Down", systemImage: "arrow.down") }
                        .disabled(isLast)
                    Divider()
                    Button(role: .destructive, action: delete) { Label("Delete Block", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel("Block \(index) actions")
            }

            TextEditor(text: $block.text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: editorMinHeight)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
        }
        .padding(.vertical, 6)
    }
}

/// Glanceable reference for the inline markers, shown from the Formatting button.
private struct FormattingHelp: View {
    private struct Marker: Identifiable {
        let id = UUID()
        let syntax: String
        let meaning: String
    }

    private let markers: [Marker] = [
        Marker(syntax: "[0.5]", meaning: "Pause for 0.5 seconds"),
        Marker(syntax: "[2]", meaning: "Pause for 2 seconds"),
        Marker(syntax: "[speed:20]", meaning: "Type faster - 20 ms per character"),
        Marker(syntax: "[speed:100]", meaning: "Type slower - 100 ms per character"),
        Marker(syntax: "[speed:default]", meaning: "Back to your set speed"),
        Marker(syntax: "[enter]", meaning: "Press Return (submits in chat apps)")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Formatting markers")
                .font(.headline)
            Text("Type these anywhere in a block to control pacing.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            ForEach(markers) { marker in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(marker.syntax)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 130, alignment: .leading)
                    Text(marker.meaning)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Divider()
            Text("A line break inside a block is inserted without submitting (Shift+Return). Use [enter] where you actually want to send. Change this in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 360)
    }
}
