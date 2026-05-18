import SwiftUI

struct MoveSheet: View {
    @ObservedObject var store: BlogStore
    @Binding var activeSheet: ActiveSheet?
    @State private var destinationID = BlogNodeID.root

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Move")
                .font(.title2)

            if let node = store.actionNode {
                Text(node.relativePath)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Picker("Destination", selection: $destinationID) {
                ForEach(filteredDestinations) { destination in
                    Text(destination.title).tag(destination.id)
                }
            }
            .pickerStyle(.menu)

            HStack {
                Spacer()
                Button("Cancel") { activeSheet = nil }
                Button("Move") {
                    store.moveActionNode(to: destinationID)
                    activeSheet = nil
                }
                .keyboardShortcut(.defaultAction)
                .disabled(store.actionNode == nil)
            }
        }
        .padding()
        .frame(width: 440)
        .onAppear {
            destinationID = BlogNodeID.root
        }
    }

    private var filteredDestinations: [CategoryDestination] {
        guard let node = store.actionNode, node.kind == .category else {
            return store.categoryDestinations
        }

        return store.categoryDestinations.filter { destination in
            let source = node.url.standardizedFileURL.path
            let target = destination.url.standardizedFileURL.path
            return target != source && !target.hasPrefix(source + "/")
        }
    }
}
