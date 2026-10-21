// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// A Home tile that shows its page live, using the views the Controls page
/// already draws.
struct NotchHomeTile: View {
    let service: NotchService
    let item: NotchHomeItem
    let highlighted: Bool
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: item.size == .wide ? 18 : 16, style: .continuous)
        content
            .frame(maxWidth: .infinity)
            .frame(height: NotchLayout.sectionTileHeight)
            .background {
                // The wide card draws its own surface.
                if item.size == .live { shape.fill(.white.opacity(0.045)) }
            }
            .overlay {
                shape.strokeBorder(.white.opacity(highlighted ? 0.55 : contrast == .increased ? 0.4 : 0), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .accessibilityIdentifier("notch.home.\(item.module.rawValue)")
    }

    @ViewBuilder private var content: some View {
        switch (item.module, item.size) {
        case (.music, .wide): NotchMusicControlsView(notch: service, height: NotchLayout.sectionTileHeight)
        case (.timer, .live): NotchTimerTile(service: service)
        case (.calendar, .live): NotchCalendarTile(service: service)
        // `homeItems` never yields another pairing.
        default: EmptyView()
        }
    }
}

/// What a Home tile's menu offers: its size where the page has more than one,
/// and a way to put it first.
struct NotchHomeMenu: View {
    let service: NotchService
    let item: NotchHomeItem
    @ObservedObject private var l10n = L10n.shared
    private var text: NotchStrings { FeatureStrings.notch(l10n.language) }

    var body: some View {
        if item.module.homeSizes.count > 1 {
            Picker(text.homeTileSize, selection: Binding(get: { item.size },
                                                         set: { service.setHomeTileSize($0, for: item.module) })) {
                ForEach(item.module.homeSizes, id: \.self) { Text(label($0)).tag($0) }
            }
            .pickerStyle(.inline)
            Divider()
        }
        Button(text.moveToStart) { service.moveHomeItemToStart(item.module) }
            .disabled(service.modules.first == item.module)
    }

    private func label(_ size: NotchHomeTileSize) -> String {
        switch size {
        case .icon: return text.homeTileIcon
        case .live: return text.homeTileLive
        case .wide: return text.homeTileWide
        }
    }
}

/// The tile's menu on a right click, and as a small button at its corner
/// while the pointer is over it. Disabled, the tile is left as it is.
struct NotchHomeTileMenus: ViewModifier {
    let service: NotchService
    let item: NotchHomeItem
    let enabled: Bool
    @ObservedObject private var l10n = L10n.shared
    @State private var hovered = false
    private var text: NotchStrings { FeatureStrings.notch(l10n.language) }

    func body(content: Content) -> some View {
        Group {
            if enabled { menus(content) } else { content }
        }
        // Typing a search stops following the pointer; the button must not
        // still show once the search is cleared.
        .onChange(of: enabled) { _, _ in hovered = false }
    }

    private func menus(_ content: Content) -> some View {
        content
            .contextMenu { NotchHomeMenu(service: service, item: item) }
            .overlay(alignment: .topTrailing) {
                if hovered {
                    Menu {
                        NotchHomeMenu(service: service, item: item)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(.white.opacity(0.16), in: Circle())
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .padding(5)
                    // With one size, the menu only moves the tile.
                    .accessibilityLabel(item.module.homeSizes.count > 1 ? text.homeTileSize : text.moveToStart)
                }
            }
            .onHover { hovered = $0 }
    }
}
