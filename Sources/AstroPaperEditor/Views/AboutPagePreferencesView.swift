import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AboutPagePreferencesView: View {
    @ObservedObject var store: BlogStore
    @State private var draft = ""
    @State private var lastLoaded = ""
    @State private var frontmatter = ""
    @State private var lastLoadedFrontmatter = ""
    @State private var message = ""
    @State private var isProfileDropTargeted = false

    private var isDirty: Bool {
        draft != lastLoaded || frontmatter != lastLoadedFrontmatter
    }

    private var profileImageSource: String? {
        AboutPageFrontmatter.stringValue(for: "profileImage", in: frontmatter)
            ?? AboutProfileImageMarkup.firstImageSource(in: draft)
    }

    private var profileImageURL: URL? {
        guard let source = profileImageSource else { return nil }
        if source.hasPrefix(ImageService.assetImagePrefix) {
            return store.resolvedAssetImageURL(source)
        }
        if source.hasPrefix("/") {
            return store.resolvedPublicURL(source)
        }
        return nil
    }

    private var profileImage: NSImage? {
        guard let profileImageURL else { return nil }
        return NSImage(contentsOf: profileImageURL)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("About Page")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("src/pages/about.md")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Spacer()

                Button {
                    reload()
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }

                Button {
                    save()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!isDirty)
            }

            GroupBox("Profile Photo") {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isProfileDropTargeted ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isProfileDropTargeted ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: 1)
                            }

                        if let profileImage {
                            Image(nsImage: profileImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 96, height: 96)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "person.crop.square")
                                    .font(.system(size: 28))
                                Text("Drop image")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 96, height: 96)
                    .onDrop(of: [UTType.fileURL], isTargeted: $isProfileDropTargeted, perform: handleProfileImageDrop)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(profileImageSource ?? "No profile image found")
                            .font(.callout)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)

                        Text(profileImageURL?.path ?? "Set profileImage in about.md frontmatter.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)

                        HStack {
                            Button {
                                chooseProfileImage()
                            } label: {
                                Label("Replace Photo", systemImage: "photo.badge.arrow.down")
                            }

                            if profileImageSource != nil {
                                Button {
                                    revealProfileImage()
                                } label: {
                                    Label("Reveal", systemImage: "folder")
                                }
                                .disabled(profileImageURL == nil)
                            }
                        }
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
            }

            TextEditor(text: $draft)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.separator, lineWidth: 1)
                }

            HStack {
                if isDirty {
                    Label("Unsaved", systemImage: "circle.fill")
                        .foregroundStyle(.orange)
                }

                Text(message)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Button {
                    store.openWebsite()
                } label: {
                    Label("Open Website", systemImage: "safari")
                }
            }
            .font(.caption)
        }
        .onAppear {
            if draft.isEmpty {
                reload()
            }
        }
    }

    private func reload() {
        do {
            let page = try store.readAboutPage()
            draft = page.body
            lastLoaded = page.body
            frontmatter = page.frontmatter
            lastLoadedFrontmatter = page.frontmatter
            message = "Loaded \(store.aboutPageURL.path)"
        } catch {
            message = error.localizedDescription
        }
    }

    private func save() {
        do {
            try store.writeAboutPage(SiteMarkdownPage(frontmatter: frontmatter, body: draft))
            lastLoaded = draft
            lastLoadedFrontmatter = frontmatter
            message = "Saved \(store.aboutPageURL.path)"
        } catch {
            message = error.localizedDescription
        }
    }

    private func chooseProfileImage() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .gif, .webP]
        panel.message = "Choose a web image to copy into public and use as the About profile photo."

        if panel.runModal() == .OK, let url = panel.url {
            replaceProfileImage(with: url)
        }
    }

    private func handleProfileImageDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let itemURL = item as? URL {
                url = itemURL
            } else if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                url = nil
            }

            guard let url else {
                return
            }
            Task { @MainActor in
                replaceProfileImage(with: url)
            }
        }

        return true
    }

    private func replaceProfileImage(with sourceURL: URL) {
        guard isSupportedProfileImage(sourceURL) else {
            message = "Choose a PNG, JPEG, GIF, or WebP image."
            return
        }

        do {
            let publicPath = try store.copyAboutProfileImage(from: sourceURL)
            frontmatter = AboutPageFrontmatter.upsertingStringValue(for: "profileImage", value: publicPath, in: frontmatter)
            if AboutPageFrontmatter.stringValue(for: "profileImageAlt", in: frontmatter) == nil {
                frontmatter = AboutPageFrontmatter.upsertingStringValue(for: "profileImageAlt", value: "강정훈 프로필 사진", in: frontmatter)
            }
            draft = AboutProfileImageMarkup.removingFirstImage(in: draft)
            message = "Profile photo copied to public\(publicPath). Save About page to keep the new reference."
        } catch {
            message = error.localizedDescription
        }
    }

    private func revealProfileImage() {
        guard let profileImageURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([profileImageURL])
    }

    private func isSupportedProfileImage(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return [UTType.png, .jpeg, .gif, .webP].contains { type.conforms(to: $0) }
    }
}

private enum AboutPageFrontmatter {
    static func stringValue(for key: String, in frontmatter: String) -> String? {
        guard let valueRange = stringValueRange(for: key, in: frontmatter) else { return nil }
        return String(frontmatter[valueRange])
    }

    static func upsertingStringValue(for key: String, value: String, in frontmatter: String) -> String {
        if let valueRange = stringValueRange(for: key, in: frontmatter) {
            var updated = frontmatter
            updated.replaceSubrange(valueRange, with: escaped(value))
            return updated
        }

        guard frontmatter.hasPrefix("---") else {
            return """
            ---
            \(key): "\(escaped(value))"
            ---
            """
        }

        let line = "\(key): \"\(escaped(value))\"\n"
        var updated = frontmatter
        if let closeRange = updated.range(of: "\n---", options: .backwards) {
            updated.insert(contentsOf: line, at: updated.index(after: closeRange.lowerBound))
        } else {
            updated.append("\n\(line)---")
        }
        return updated
    }

    private static func stringValueRange(for key: String, in frontmatter: String) -> Range<String.Index>? {
        guard let regex = try? NSRegularExpression(pattern: #"(?m)^(\#(key)\s*:\s*['"])([^'"]*)(['"]\s*)$"#) else {
            return nil
        }
        let nsRange = NSRange(frontmatter.startIndex..<frontmatter.endIndex, in: frontmatter)
        guard let match = regex.firstMatch(in: frontmatter, range: nsRange),
              let range = Range(match.range(at: 2), in: frontmatter) else {
            return nil
        }
        return range
    }

    private static func escaped(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

private enum AboutProfileImageMarkup {
    static func firstImageSource(in markdown: String) -> String? {
        guard let range = firstImageSourceRange(in: markdown) else { return nil }
        return String(markdown[range])
    }

    static func removingFirstImage(in markdown: String) -> String {
        guard let range = firstImageRange(in: markdown) else { return markdown }
        var updated = markdown
        updated.removeSubrange(range)
        return updated.trimmingLeadingNewlines()
    }

    private static func firstImageSourceRange(in markdown: String) -> Range<String.Index>? {
        if let range = capturedRange(pattern: #"(?is)<img\b[^>]*\bsrc\s*=\s*(['"])(.*?)\1[^>]*>"#, group: 2, in: markdown) {
            return range
        }
        return capturedRange(pattern: #"!\[[^\]]*\]\(([^)]+)\)"#, group: 1, in: markdown)
    }

    private static func firstImageRange(in markdown: String) -> Range<String.Index>? {
        if let range = capturedRange(pattern: #"(?is)<img\b[^>]*>\s*"#, group: 0, in: markdown) {
            return range
        }
        return capturedRange(pattern: #"(?m)^\s*!\[[^\]]*\]\([^)]+\)\s*\n*"#, group: 0, in: markdown)
    }

    private static func capturedRange(pattern: String, group: Int, in text: String) -> Range<String.Index>? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              group < match.numberOfRanges,
              let range = Range(match.range(at: group), in: text) else {
            return nil
        }
        return range
    }
}
