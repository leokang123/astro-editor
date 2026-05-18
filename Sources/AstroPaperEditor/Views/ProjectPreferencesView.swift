import AppKit
import SwiftUI

struct ProjectPreferencesView: View {
    @ObservedObject var store: BlogStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Project")
                .font(.title2)
                .fontWeight(.semibold)

            GroupBox {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 12) {
                    GridRow {
                        Text("Root")
                            .foregroundStyle(.secondary)
                        Text(store.hasProject ? store.projectRoot.path : "No project selected")
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }

                    if store.hasProject {
                        GridRow {
                            Text("Blog")
                                .foregroundStyle(.secondary)
                            Text(store.blogRoot.path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                        }

                        GridRow {
                            Text("About")
                                .foregroundStyle(.secondary)
                            Text(store.aboutPageURL.path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                        }

                        GridRow {
                            Text("Config")
                                .foregroundStyle(.secondary)
                            Text(store.configURL.path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                        }

                        GridRow {
                            Text("User settings")
                                .foregroundStyle(.secondary)
                            Text(store.userSettingsURL.path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(10)
            }

            HStack {
                Button {
                    store.chooseProjectFolder()
                } label: {
                    Label("Choose Project Folder", systemImage: "folder.badge.gearshape")
                }

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([store.projectRoot])
                } label: {
                    Label("Show in Finder", systemImage: "finder")
                }
                .disabled(!store.hasProject)
            }

            Spacer()
        }
    }
}
