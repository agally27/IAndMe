import SwiftUI
import SwiftData
import PhotosUI

/// The person's own corner: name, a few numbers, what the app remembers, privacy, export, deletion.
/// Deliberately secondary to the journal itself.
struct ProfileView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @Query private var entries: [JournalEntry]
    @State private var name = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var stats = JournalStatistics.empty
    @State private var showDeleteAll = false
    @State private var showDeleteAllFinal = false
    @State private var showRemoveSample = false
    @State private var isInstallingSample = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    identity
                    numbers
                    sections
                    dataControls
                    about
                }
                .pageHorizontalPadding()
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.xxl)
            }
            .background(CanvasBackground())
            .navigationTitle("You")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .appDestinations()
            .onAppear {
                name = profile?.name ?? ""
                stats = services.repository.statistics()
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        let stored = try? services.media.storePhoto(image.downscaled(maxDimension: 600))
                        if let old = profile?.avatarFileName { services.media.deletePhoto(named: old) }
                        profile?.avatarFileName = stored?.fileName
                        try? services.repository.save()
                    }
                    photoItem = nil
                }
            }
            .confirmationDialog("Remove the sample life?", isPresented: $showRemoveSample, titleVisibility: .visible) {
                Button("Remove sample life", role: .destructive) {
                    try? services.repository.deleteSampleLife()
                    services.refreshInsights()
                    stats = services.repository.statistics()
                }
                Button("Keep it", role: .cancel) {}
            } message: {
                Text("Your own moments stay. Only the fictional sample moments, memories and chapters are removed.")
            }
            .confirmationDialog("Delete all your moments?", isPresented: $showDeleteAll, titleVisibility: .visible) {
                Button("Continue", role: .destructive) { showDeleteAllFinal = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes every moment, photo, recording, memory, conversation and chapter from this phone. There is no copy anywhere else.")
            }
            .alert("This can't be undone", isPresented: $showDeleteAllFinal) {
                Button("Delete everything", role: .destructive) {
                    try? services.repository.deleteEverything()
                    stats = services.repository.statistics()
                }
                Button("Keep my journal", role: .cancel) {}
            } message: {
                Text("If you want a copy first, export your story before deleting.")
            }
        }
    }

    private var identity: some View {
        HStack(spacing: Theme.Spacing.md) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    ProfileAvatar(profile: profile, size: 72)
                    Image(systemName: "camera.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.canvasRaised)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Theme.Colors.accent))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change profile photo")
            VStack(alignment: .leading, spacing: 4) {
                TextField("Your name", text: $name)
                    .font(.title2Serif)
                    .foregroundStyle(Theme.Colors.ink)
                    .textContentType(.givenName)
                    .submitLabel(.done)
                    .onSubmit { saveName() }
                    .onChange(of: name) { saveName() }
                    .accessibilityLabel("Your name")
                if let since = stats.firstEntryDate {
                    Text("Keeping moments since \(since.formatted(.dateTime.month(.wide).year()))")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.inkSecondary)
                }
            }
        }
    }

    private var numbers: some View {
        let items: [(String, String)] = [
            ("\(stats.entryCount)", stats.entryCount == 1 ? "moment" : "moments"),
            ("\(stats.daysWithEntries)", stats.daysWithEntries == 1 ? "day" : "days"),
            ("\(stats.photoCount)", stats.photoCount == 1 ? "photo" : "photos"),
            (DurationFormatting.short(stats.voiceDuration), "of voice"),
            ("\(stats.keptCount)", "kept")
        ]
        return HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(spacing: 2) {
                    Text(item.0).font(.title3Serif).foregroundStyle(Theme.Colors.ink).monospacedDigit()
                    Text(item.1).font(.caption2).foregroundStyle(Theme.Colors.inkTertiary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.vertical, Theme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).fill(Theme.Colors.surface))
    }

    private var sections: some View {
        VStack(spacing: 0) {
            NavigationLink(value: AppScreen.whatIRemember) {
                SettingsRow(title: "What I remember", detail: "\(stats.conceptCount) people, places and themes", systemImage: "brain")
            }
            .buttonStyle(.plain)
            Hairline()
            NavigationLink(value: AppScreen.privacy) {
                SettingsRow(title: "Privacy", detail: "Everything stays on this phone", systemImage: "lock")
            }
            .buttonStyle(.plain)
            Hairline()
            NavigationLink(value: AppScreen.export) {
                SettingsRow(title: "Export your story", detail: "Readable text or structured data", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).fill(Theme.Colors.surface))
    }

    private var dataControls: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Your data").eyebrowStyle()
            VStack(spacing: 0) {
                if profile?.usesSampleLife == true || entries.contains(where: \.isSample) {
                    Button { showRemoveSample = true } label: {
                        SettingsRow(title: "Remove the sample life", detail: "Keeps your own moments", systemImage: "sparkles", tint: Theme.Colors.ink)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("profile.removeSample")
                } else {
                    Button {
                        isInstallingSample = true
                        try? services.sample.installSampleLife()
                        services.refreshInsights()
                        stats = services.repository.statistics()
                        isInstallingSample = false
                    } label: {
                        SettingsRow(title: "Explore a sample life", detail: "Five months of fictional moments, clearly marked", systemImage: "sparkles", tint: Theme.Colors.ink)
                    }
                    .buttonStyle(.plain)
                    .disabled(isInstallingSample)
                }
                Hairline()
                Button { showDeleteAll = true } label: {
                    SettingsRow(title: "Delete all my moments", detail: "Removes everything from this phone", systemImage: "trash", tint: .red)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile.deleteAll")
            }
            .padding(.horizontal, Theme.Spacing.md)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).fill(Theme.Colors.surface))
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                BrandMark(size: 28)
                Text(Brand.name).font(.headlineSerif).foregroundStyle(Theme.Colors.ink)
                Spacer()
                Text("Prototype \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                    .font(.caption).foregroundStyle(Theme.Colors.inkTertiary)
            }
            Text(Brand.tagline)
                .font(.caption)
                .foregroundStyle(Theme.Colors.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, Theme.Spacing.sm)
    }

    private func saveName() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let profile, profile.name != trimmed else { return }
        profile.name = trimmed
        try? services.repository.save()
    }
}

struct SettingsRow: View {
    var title: String
    var detail: String? = nil
    var systemImage: String
    var tint: Color = Theme.Colors.ink

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: systemImage)
                .foregroundStyle(tint == Theme.Colors.ink ? Theme.Colors.accent : tint)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body).foregroundStyle(tint)
                if let detail { Text(detail).font(.caption).foregroundStyle(Theme.Colors.inkTertiary) }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(Theme.Colors.inkTertiary)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
