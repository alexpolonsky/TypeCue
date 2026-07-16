import SwiftUI

/// Glanceable content of the floating panel: active script, position, and every block with
/// its state clearly distinguished (already typed, currently typing, next/armed, upcoming).
/// Doubles as a teleprompter during recording, so it shows full block text, not previews.
struct ScriptPanelView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Leading icon column width, so every block's text left-aligns regardless of glyph.
    /// Scales with Dynamic Type so the icon column keeps pace with larger text sizes.
    @ScaledMetric private var iconColumnWidth: CGFloat = 20

    var body: some View {
        #if DEBUG
        Signposts.ui.emitEvent("panel.body")
        #endif
        return content
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider()
            if let script = coordinator.activeScript, !script.blocks.isEmpty {
                blockList(script)
            } else {
                emptyState
            }
        }
        .padding(14)
        .frame(minWidth: 300, maxWidth: .infinity, minHeight: 300, maxHeight: .infinity, alignment: .top)
        // A vibrant background so the teleprompter stays legible over busy desktops during
        // recording. A full-surface material (not Liquid Glass, which is for controls
        // floating over content) is the right fit for the panel's base layer.
        .background(.ultraThinMaterial)
        // Blocked presses (secure field, missing permission) flash a banner here too, since
        // the menu dropdown is invisible mid-recording. Auto-dismisses with the flash flag.
        .overlay(alignment: .top) {
            if coordinator.isFlashingWarning, let warning = coordinator.warning {
                warningBanner(warning)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: coordinator.isFlashingWarning)
    }

    private func warningBanner(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.orange.opacity(0.45)))
        .shadow(radius: 4, y: 2)
        .padding(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Warning: \(text)")
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            scriptMenu
            Spacer(minLength: 8)
            Text(positionText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    /// Non-intrusive script switcher: the header title is a menu of all scripts. Switching
    /// is a deliberate, non-recording action, so briefly focusing the panel is acceptable.
    private var scriptMenu: some View {
        Menu {
            ForEach(coordinator.store.scripts) { script in
                Button {
                    coordinator.setActiveScript(script.id)
                } label: {
                    if script.id == coordinator.session.activeScriptID {
                        Label(script.name.isEmpty ? "Untitled" : script.name, systemImage: "checkmark")
                    } else {
                        Text(script.name.isEmpty ? "Untitled" : script.name)
                    }
                }
            }
            if !coordinator.store.scripts.isEmpty {
                Divider()
            }
            Button("None") { coordinator.setActiveScript(nil) }
        } label: {
            HStack(spacing: 4) {
                Text(coordinator.activeScript?.name ?? "TypeCue")
                    .font(.headline)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(coordinator.store.scripts.isEmpty)
    }

    @ViewBuilder
    private var emptyState: some View {
        if coordinator.activeScript == nil {
            ContentUnavailableView {
                Label("No active script", systemImage: "list.bullet.rectangle")
            } description: {
                Text(coordinator.store.scripts.isEmpty
                     ? "Create a script in the editor to get started."
                     : "Pick a script from the menu above.")
            } actions: {
                if coordinator.store.scripts.isEmpty {
                    Button("Edit Scripts") { coordinator.openEditor() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView {
                Label("No blocks yet", systemImage: "text.append")
            } description: {
                Text("Add text blocks to this script in the editor.")
            } actions: {
                Button("Edit Scripts") { coordinator.openEditor() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Block list

    @ViewBuilder
    private func blockList(_ script: Script) -> some View {
        let states = panelRowStates(
            blockCount: script.blocks.count,
            sessionState: coordinator.session.state,
            isTyping: coordinator.isTyping
        )
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(script.blocks.indices, id: \.self) { index in
                        let state = states.indices.contains(index) ? states[index] : .upcoming
                        blockRow(script.blocks[index], index: index, state: state)
                            .id(index)
                    }
                }
            }
            .onChange(of: activeRowIndex(states)) { _, newValue in
                guard let newValue else { return }
                if reduceMotion {
                    proxy.scrollTo(newValue, anchor: .center)
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
        }
    }

    private func blockRow(_ block: TextBlock, index: Int, state: PanelRowState) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol(for: state))
                .foregroundStyle(iconColor(for: state))
                .font(.body)
                .symbolEffect(.pulse, isActive: state == .typing)
                .frame(width: iconColumnWidth, alignment: .center)
                .accessibilityHidden(true)
            Text(displayText(block))
                .font(font(for: state))
                .foregroundStyle(textColor(for: state))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(rowBackground(for: state))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.75), value: state)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Block \(index + 1), \(accessibilityStateLabel(for: state))")
        .accessibilityValue(displayText(block))
    }

    // MARK: - Derived values

    /// Row to keep visible: the typing block if any, otherwise the next/armed block.
    private func activeRowIndex(_ states: [PanelRowState]) -> Int? {
        states.firstIndex(of: .typing) ?? states.firstIndex(of: .next)
    }

    private var positionText: String {
        switch coordinator.session.state {
        case .idle: return "\u{2014}"
        case .armed(let nextIndex, let total): return "\(nextIndex + 1) / \(total)"
        case .complete(let total): return total == 0 ? "empty" : "done"
        }
    }

    private func symbol(for state: PanelRowState) -> String {
        switch state {
        case .played: return "checkmark.circle.fill"
        case .typing: return "ellipsis"
        case .next: return "arrowtriangle.right.fill"
        case .upcoming: return "circle"
        }
    }

    private func iconColor(for state: PanelRowState) -> Color {
        switch state {
        case .played: return .secondary
        case .typing, .next: return .accentColor
        case .upcoming: return .secondary
        }
    }

    /// Type ramp that separates the armed/typing block (emphasized) from already-typed
    /// (de-emphasized) and upcoming (present but clearly "later").
    private func font(for state: PanelRowState) -> Font {
        switch state {
        case .typing, .next: return .body.weight(.semibold)
        case .played: return .callout
        case .upcoming: return .callout
        }
    }

    private func textColor(for state: PanelRowState) -> Color {
        switch state {
        case .played: return .secondary
        case .typing, .next: return .primary
        case .upcoming: return .secondary
        }
    }

    private func accessibilityStateLabel(for state: PanelRowState) -> String {
        switch state {
        case .played: return "typed"
        case .typing: return "currently typing"
        case .next: return "next to type"
        case .upcoming: return "upcoming"
        }
    }

    private func rowBackground(for state: PanelRowState) -> Color {
        switch state {
        case .typing: return Color.accentColor.opacity(0.20)
        case .next: return Color.accentColor.opacity(0.10)
        case .played, .upcoming: return .clear
        }
    }

    private func displayText(_ block: TextBlock) -> String {
        block.text.isEmpty ? "(empty block)" : block.text
    }
}
