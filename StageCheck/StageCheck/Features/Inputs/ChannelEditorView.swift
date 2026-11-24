import SwiftUI

struct ChannelEditorView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let projectID: UUID
    let channelID: UUID?
    @State private var c = InputChannel(channelNumber: 1, name: "")
    @State private var loaded = false

    var body: some View {
        let others = (store.project(projectID)?.channels ?? []).filter { $0.id != c.id }
        let dupSB = c.hasStageBox && others.contains { $0.hasStageBox && $0.stageBoxInput.trimmed.lowercased() == c.stageBoxInput.trimmed.lowercased() && $0.stageBoxName.trimmed.lowercased() == c.stageBoxName.trimmed.lowercased() }
        let dupCC = c.hasConsole && others.contains { $0.hasConsole && $0.consoleChannel.trimmed.lowercased() == c.consoleChannel.trimmed.lowercased() && $0.consoleName.trimmed.lowercased() == c.consoleName.trimmed.lowercased() }
        let dupNum = others.contains { $0.channelNumber == c.channelNumber }
        Form {
            Section("Source") {
                Stepper(value: $c.channelNumber, in: 1...999) {
                    HStack { Text("Channel"); Spacer(); Text("\(c.channelNumber)").font(.mono(.body)) }
                }
                if dupNum { warn("Channel number already used") }
                TextField("Channel Name", text: $c.name)
                TextField("Source Name", text: $c.sourceName)
                Picker("Input Type", selection: $c.inputType) {
                    ForEach(InputType.allCases) { Label($0.rawValue, systemImage: $0.icon).tag($0) }
                }
                TextField("Equipment Model", text: $c.equipmentModel)
            }.rowBG()
            Section("Patch") {
                TextField("Stage Box Name", text: $c.stageBoxName)
                TextField("Stage Box Input", text: $c.stageBoxInput).font(.mono(.body, weight: .regular))
                if dupSB { warn("Stage box input is used by another channel") }
                TextField("Console Name", text: $c.consoleName)
                TextField("Console Channel", text: $c.consoleChannel).font(.mono(.body, weight: .regular))
                if dupCC { warn("Console channel is used by another channel") }
                TextField("Cable Label", text: $c.cableLabel)
            }.rowBG()
            Section {
                Toggle("Phantom Power (+48V) Required", isOn: $c.phantomPowerRequired)
                TextField("Gain Reference", text: $c.gainReference)
                TextField("Pan", text: $c.pan)
                TextField("Monitor Notes", text: $c.monitorNotes, axis: .vertical).lineLimit(1...4)
            } header: { Text("Technical Reference") } footer: { Text("Reference values entered by you. StageCheck does not control or measure audio equipment.") }
            .rowBG()
            Section("Color Tag") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ColorTag.allCases) { t in
                            Button { c.colorTag = t } label: {
                                Circle().fill(Theme.color(t)).frame(width: 30, height: 30)
                                    .overlay(Circle().stroke(Theme.text, lineWidth: c.colorTag == t ? 2 : 0).padding(-3))
                                    .overlay { if t == .none { Image(systemName: "slash.circle").foregroundStyle(Theme.text2) } }
                            }
                            .buttonStyle(.plain).accessibilityLabel(t.rawValue).accessibilityAddTraits(c.colorTag == t ? .isSelected : [])
                        }
                    }.padding(6)
                }
            }.rowBG()
            Section("Notes") {
                TextField("Additional notes", text: $c.notes, axis: .vertical).lineLimit(2...6)
            }.rowBG()
        }
        .darkList()
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(channelID == nil ? "New Input" : "Edit Input")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { store.upsert(c, in: projectID); Haptics.success(); dismiss() }
                    .fontWeight(.semibold).disabled(c.name.trimmed.isEmpty)
            }
        }
        .onAppear {
            guard !loaded else { return }; loaded = true
            if let id = channelID, let ex = store.project(projectID)?.channels.first(where: { $0.id == id }) { c = ex }
            else {
                let n = store.nextChannelNumber(projectID)
                c = InputChannel(channelNumber: n, name: "", stageBoxName: store.project(projectID)?.channels.last?.stageBoxName ?? "")
            }
        }
    }

    private func warn(_ s: String) -> some View {
        Label(s, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(Theme.warning)
    }
}
