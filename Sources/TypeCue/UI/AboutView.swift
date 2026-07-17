import SwiftUI

/// The About tab of the main window: identity, links, and the open-source
/// acknowledgements (the bundled third-party license texts).
struct AboutView: View {
    @State private var showLicenses = false

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    }
    private var licensesText: String {
        guard let url = Bundle.main.url(forResource: "THIRD-PARTY-LICENSES", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "Built with KeyboardShortcuts (\u{00A9} Sindre Sorhus) and Sauce (\u{00A9} Clipy Project), both MIT licensed."
        }
        return text
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if let icon = NSApp.applicationIconImage {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 96, height: 96)
                }
                Text("TypeCue")
                    .font(.title2.bold())
                Text("Version \(version)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .help("Build \(build)")
                Text("\u{00A9} 2026 Alex Polonsky \u{00B7} MIT License")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Link("Website", destination: URL(string: "https://typecue.app")!)
                    Text("\u{00B7}").foregroundStyle(.tertiary)
                    Link("GitHub", destination: URL(string: "https://github.com/alexpolonsky/TypeCue")!)
                    Text("\u{00B7}").foregroundStyle(.tertiary)
                    Link("Report an Issue", destination: URL(string: "https://github.com/alexpolonsky/TypeCue/issues")!)
                }
                .font(.callout)
                .padding(.top, 2)

                DisclosureGroup("Acknowledgements", isExpanded: $showLicenses) {
                    Text(licensesText)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(.top, 6)
                }
                .frame(maxWidth: 460)
                .padding(.top, 14)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
        }
    }
}
