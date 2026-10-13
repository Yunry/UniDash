//
//  CampusQuickLinksView.swift
//  UniDash
//
//  Campus quick-launch links for Moodle, LSF, LRZ Webmail, OPAC, Eduroam, and student services.
//

import SwiftUI

struct CampusQuickLinksView: View {
    @State private var selectedCategory: CampusLinkCategory = .all
    @State private var searchText: String = ""
    @State private var activeURL: URL? = nil
    @State private var activeTitle: String = ""
    @Environment(\.openURL) private var openURL

    private let allLinks = CampusLink.defaultLinks

    private var filteredLinks: [CampusLink] {
        allLinks.filter { link in
            let matchesCategory = (selectedCategory == .all || link.category == selectedCategory)
            let matchesSearch = searchText.isEmpty ||
                link.title.localizedCaseInsensitiveContains(searchText) ||
                link.subtitle.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 14)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Category Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CampusLinkCategory.allCases, id: \.self) { cat in
                        Button {
                            selectedCategory = cat
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: cat.icon)
                                Text(cat.rawValue)
                            }
                            .font(.caption)
                            .fontWeight(selectedCategory == cat ? .semibold : .regular)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedCategory == cat ? Color.blue : Color.secondary.opacity(0.12))
                            .foregroundStyle(selectedCategory == cat ? .white : .primary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }

            // Links Grid
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(filteredLinks) { link in
                    CampusLinkCard(
                        link: link,
                        onOpenInApp: {
                            if let url = URL(string: link.url) {
                                activeURL = url
                                activeTitle = link.title
                            }
                        },
                        onOpenSafari: {
                            if let url = URL(string: link.url) {
                                openURL(url)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
        .sheet(item: Binding<IdentifiableURL?>(
            get: { activeURL.map { IdentifiableURL(url: $0, title: activeTitle) } },
            set: { activeURL = $0?.url }
        )) { item in
            InAppBrowserSheet(url: item.url, title: item.title)
        }
    }
}

struct IdentifiableURL: Identifiable {
    var id: String { url.absoluteString }
    let url: URL
    let title: String
}

// MARK: - Campus Link Card

struct CampusLinkCard: View {
    let link: CampusLink
    var onOpenInApp: () -> Void
    var onOpenSafari: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: link.colorHex).opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: link.iconName)
                    .font(.title3)
                    .foregroundStyle(Color(hex: link.colorHex))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(link.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    if link.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(link.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // Quick launch buttons
            HStack(spacing: 6) {
                Button(action: onOpenInApp) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("In-App öffnen")

                Button(action: onOpenSafari) {
                    Image(systemName: "safari")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("In Safari mit SSO öffnen")
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
}
