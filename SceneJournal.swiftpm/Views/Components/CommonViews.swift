import SwiftUI

struct HeaderPanel: View {
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Capture any live moment")
                .font(.title3.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            Text("Concerts, Broadway, and any other memory in one place.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Label("\(total)", systemImage: "tray.full.fill")
                    .font(.headline)
                Text(total == 1 ? "entry" : "entries")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.35), lineWidth: 0.8)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Capture any live moment")
        .accessibilityValue("\(total) \(total == 1 ? "entry" : "entries")")
    }
}

struct FilterChips: View {
    @Binding var activeFilter: EntryFilter
    let filters: [EntryFilter]
    let onAddCategory: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters, id: \.id) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            activeFilter = filter
                        }
                    } label: {
                        Text(filter.title)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(chipBackground(for: filter), in: Capsule())
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(filter.title) filter")
                    .accessibilityHint("Shows \(filter.title.lowercased()) entries")
                    .accessibilityAddTraits(activeFilter == filter ? .isSelected : [])
                }

                Button(action: onAddCategory) {
                    Label("Add", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add Category")
                .accessibilityHint("Create a custom category and filter")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Filters")
    }

    private func chipBackground(for filter: EntryFilter) -> some ShapeStyle {
        if activeFilter == filter {
            return AnyShapeStyle(filter.tint.opacity(0.22))
        }
        return AnyShapeStyle(.ultraThinMaterial)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.house")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("No entries yet")
                .font(.headline)
            Text("Tap + to create your first record.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct EntryRowView: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(entry.type.displayName)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(entry.type.badgeColor.opacity(0.2), in: Capsule())

                Spacer()

                Text(entry.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(entry.title)
                .font(.headline)

            if !entry.venue.isEmpty {
                Label(entry.venue, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !entry.people.isEmpty {
                Label(entry.people, systemImage: "person.2")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                if !entry.photos.isEmpty {
                    Label("\(entry.photos.count)", systemImage: "photo")
                }
                if !entry.tags.isEmpty {
                    Label("\(entry.tags.count)", systemImage: "tag")
                }
                if !entry.customFields.isEmpty {
                    Label("\(entry.customFields.count)", systemImage: "square.text.square")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.35), lineWidth: 0.7)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entryAccessibilityLabel)
        .accessibilityValue(entryAccessibilityValue)
    }

    private var entryAccessibilityLabel: String {
        "\(entry.type.displayName): \(entry.title)"
    }

    private var entryAccessibilityValue: String {
        var parts: [String] = [entry.date.formatted(date: .abbreviated, time: .omitted)]
        if !entry.venue.isEmpty {
            parts.append("Venue \(entry.venue)")
        }
        if !entry.people.isEmpty {
            parts.append("People \(entry.people)")
        }
        if !entry.photos.isEmpty {
            parts.append("\(entry.photos.count) photos")
        }
        if !entry.tags.isEmpty {
            parts.append("\(entry.tags.count) tags")
        }
        if !entry.customFields.isEmpty {
            parts.append("\(entry.customFields.count) custom fields")
        }
        return parts.joined(separator: ", ")
    }
}

struct PhotoStripView: View {
    let photos: [EntryPhoto]
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(photos) { photo in
                    EntryPhotoView(photo: photo)
                        .frame(width: width, height: height)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Photos")
        .accessibilityValue("\(photos.count) items")
    }
}

private struct EntryPhotoView: View {
    let photo: EntryPhoto

    var body: some View {
        Group {
            if let data = photo.data, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .accessibilityLabel("Photo")
            } else if let remoteURL = photo.remoteURL, let url = URL(string: remoteURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                            .accessibilityLabel("Photo")
                    case .failure:
                        placeholder
                    case .empty:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            Rectangle().fill(.gray.opacity(0.15))
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .accessibilityLabel("Photo unavailable")
    }
}
