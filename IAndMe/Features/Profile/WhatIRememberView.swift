import SwiftUI
import SwiftData

/// Full transparency over the memory layer: everything the app recognises, where it came from,
/// and the ability to correct or forget any of it.
struct WhatIRememberView: View {
    @Environment(AppServices.self) private var services
    @Query(sort: \MemoryConcept.mentionCount, order: .reverse) private var concepts: [MemoryConcept]
    @State private var showAdd = false
    @State private var newName = ""
    @State private var newNote = ""
    @State private var newKind: ConceptKind = .person
    @State private var showForgotten = false

    private var remembered: [MemoryConcept] { concepts.filter { !$0.isForgotten } }
    private var forgotten: [MemoryConcept] { concepts.filter(\.isForgotten) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                Text("These are the people, places, themes and dates \(Brand.name) has come to recognise in your moments. It uses them to connect things and to talk with you. You can correct any of it, or ask it to forget.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(ConceptKind.allCases, id: \.self) { kind in
                    let items = remembered.filter { $0.kind == kind }
                    if !items.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Label(kind.pluralLabel, systemImage: kind.systemImage).eyebrowStyle()
                            VStack(spacing: 0) {
                                ForEach(items) { concept in
                                    NavigationLink(value: concept) {
                                        HStack(spacing: Theme.Spacing.sm) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(concept.name).font(.body).foregroundStyle(Theme.Colors.ink)
                                                Text(concept.note ?? concept.source.label).font(.caption).foregroundStyle(Theme.Colors.inkTertiary).lineLimit(1)
                                            }
                                            Spacer()
                                            if kind != .importantDate {
                                                Text("\(concept.entries.count)").font(.caption).foregroundStyle(Theme.Colors.inkTertiary)
                                            }
                                            Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(Theme.Colors.inkTertiary)
                                        }
                                        .padding(.vertical, 10)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    if concept.id != items.last?.id { Hairline() }
                                }
                            }
                            .padding(.horizontal, Theme.Spacing.md)
                            .background(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).fill(Theme.Colors.surface))
                        }
                    }
                }
                if remembered.isEmpty {
                    Text("Nothing yet. As you mention people and places, they'll appear here.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.inkSecondary)
                }
                Button { showAdd = true } label: {
                    Label("Tell me something to remember", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                if !forgotten.isEmpty {
                    DisclosureGroup(isExpanded: $showForgotten) {
                        VStack(spacing: 0) {
                            ForEach(forgotten) { concept in
                                HStack {
                                    Text(concept.name).font(.body).foregroundStyle(Theme.Colors.inkSecondary)
                                    Spacer()
                                    Button("Remember again") {
                                        concept.isForgotten = false
                                        try? services.repository.save()
                                    }
                                    .font(.caption.weight(.semibold))
                                }
                                .padding(.vertical, 10)
                                if concept.id != forgotten.last?.id { Hairline() }
                            }
                        }
                        .padding(.top, Theme.Spacing.xs)
                    } label: {
                        Text("Forgotten (\(forgotten.count))").eyebrowStyle()
                    }
                    .tint(Theme.Colors.inkSecondary)
                }
            }
            .pageHorizontalPadding()
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .background(CanvasBackground())
        .navigationTitle("What I remember")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAdd) { addSheet }
    }

    private var addSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Kind", selection: $newKind) {
                        ForEach([ConceptKind.person, .place, .theme], id: \.self) { Text($0.label).tag($0) }
                    }
                    TextField("Name", text: $newName)
                    TextField("A note, in your words", text: $newNote, axis: .vertical)
                } footer: {
                    Text("For example: “Priya — Tom's partner. Moving to Edinburgh with him.”")
                }
            }
            .navigationTitle("Something to remember")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showAdd = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Remember") {
                        let concept = MemoryConcept(name: newName.trimmingCharacters(in: .whitespaces), kind: newKind, note: newNote.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty, source: .user)
                        services.repository.modelContext.insert(concept)
                        try? services.repository.save()
                        for entry in services.repository.allEntries() { services.linkConcepts(for: entry) }
                        services.refreshInsights()
                        newName = ""; newNote = ""
                        showAdd = false
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("Your journal is yours")
                    .font(.titleSerif)
                    .foregroundStyle(Theme.Colors.ink)
                PrivacyPoint(systemImage: "iphone", title: "Stored on this phone", detail: "Every moment, photo, recording, memory and conversation is kept in the app's own storage on this device. This prototype has no account and no server.")
                PrivacyPoint(systemImage: "wifi.slash", title: "Works without a connection", detail: "Nothing here needs the internet. The companion, the insights and the story chapters are all worked out locally.")
                PrivacyPoint(systemImage: "waveform", title: "Voice stays local", detail: "Recordings are saved as files on this phone. If you ask for a transcript, it is made on-device using Apple's speech recognition and the audio is never uploaded.")
                PrivacyPoint(systemImage: "eye", title: "You can see what's remembered", detail: "Everything the app recognises — people, places, themes, dates — is listed under What I remember, with where it came from. Forget any of it at any time.")
                PrivacyPoint(systemImage: "square.and.arrow.up", title: "You can take it with you", detail: "Export your whole journal as readable text or structured data whenever you like.")
                PrivacyPoint(systemImage: "trash", title: "You can delete it", detail: "Deleting removes everything from this phone. Because there is no copy elsewhere, deletion is final.")
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("What a full release would add").eyebrowStyle()
                    Text("Encryption of the local store and media, optional end-to-end encrypted sync, explicit controls over what the companion may see, a privacy policy, and consent for any processing that leaves the device. None of that exists in this prototype, and no data leaves the phone.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, Theme.Spacing.sm)
            }
            .pageHorizontalPadding()
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .background(CanvasBackground())
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrivacyPoint: View {
    var systemImage: String
    var title: String
    var detail: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Theme.Colors.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(Theme.Colors.ink)
                Text(detail).font(.subheadline).foregroundStyle(Theme.Colors.inkSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct ExportView: View {
    @Environment(AppServices.self) private var services
    @State private var format: ExportService.Format = .markdown
    @State private var exportedURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("Your story, in a form you own")
                    .font(.titleSerif)
                    .foregroundStyle(Theme.Colors.ink)
                Text("Exports every moment with its date, feeling, place, words and transcripts. Photos and recordings are referenced by file name; a full release would bundle them too.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Picker("Format", selection: $format) {
                    ForEach(ExportService.Format.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Button("Prepare export") {
                    do {
                        exportedURL = try services.export.export(format: format)
                        errorMessage = nil
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                .buttonStyle(.secondary)
                if let exportedURL {
                    ShareLink(item: exportedURL) {
                        Label("Share \(exportedURL.lastPathComponent)", systemImage: "square.and.arrow.up")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                }
                if let errorMessage {
                    Text(errorMessage).font(.caption).foregroundStyle(.red)
                }
            }
            .pageHorizontalPadding()
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .background(CanvasBackground())
        .navigationTitle("Export")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: format) { exportedURL = nil }
    }
}
