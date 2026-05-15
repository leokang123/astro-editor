import SwiftUI

struct NewCategorySheet: View {
    @ObservedObject var store: BlogStore
    @Binding var activeSheet: ActiveSheet?
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Category")
                .font(.title2)
            TextField("Category name", text: $name)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") { activeSheet = nil }
                Button("Create") {
                    store.createCategory(named: name, parentID: store.selectionID)
                    activeSheet = nil
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 380)
    }
}
