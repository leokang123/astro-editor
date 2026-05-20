import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct AboutProfilePhotoSection: View {
    let profileImageSource: String?
    let profileImageURL: URL?
    let onReplace: (URL) -> Void
    let onInvalidImage: () -> Void

    @State private var isDropTargeted = false

    private var profileImage: NSImage? {
        ImageCache.image(at: profileImageURL)
    }

    private var profileImageDisplayName: String {
        if let profileImageURL {
            return profileImageURL.lastPathComponent
        }
        if profileImageSource != nil {
            return "Profile photo"
        }
        return "No profile photo found"
    }

    private var profileImageDetailText: String {
        if let profileImageURL {
            return profileImageURL.displayPath
        }
        if profileImageSource != nil {
            return "Profile photo file not found."
        }
        return "No profile photo selected."
    }

    var body: some View {
        GroupBox("Profile Photo") {
            HStack(alignment: .center, spacing: 14) {
                dropPreview

                VStack(alignment: .leading, spacing: 8) {
                    Text(profileImageDisplayName)
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)

                    Text(profileImageDetailText)
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
    }

    private var dropPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(isDropTargeted ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isDropTargeted ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: 1)
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
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted, perform: handleProfileImageDrop)
    }

    private func chooseProfileImage() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .gif, .webP]
        panel.message = "Choose an image for your profile photo."

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

            guard let url else { return }
            Task { @MainActor in
                replaceProfileImage(with: url)
            }
        }

        return true
    }

    private func replaceProfileImage(with sourceURL: URL) {
        guard isSupportedProfileImage(sourceURL) else {
            onInvalidImage()
            return
        }
        onReplace(sourceURL)
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
