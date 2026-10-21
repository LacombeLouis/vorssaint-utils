// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum NotchHomeTests {
    static func run(_ suite: TestSuite) {
        offeredSizes(suite)
        storage(suite)
        rowLayout(suite)
        arrowKeys(suite)
        moveToStart(suite)
        galleryGeometry(suite)
    }

    private static func items(_ modules: [NotchModule], wide: Set<NotchModule> = []) -> [NotchHomeItem] {
        modules.map { NotchHomeItem(module: $0, size: wide.contains($0) ? .wide : .icon) }
    }

    private static func offeredSizes(_ suite: TestSuite) {
        suite.expect(NotchModule.allCases.allSatisfy { $0.homeSizes.first == .icon && Set($0.homeSizes).count == $0.homeSizes.count },
                     "every page offers its icon first, once")
        suite.expect(NotchModule.music.homeSizes == [.icon, .wide]
               && NotchModule.timer.homeSizes == [.icon, .live] && NotchModule.calendar.homeSizes == [.icon, .live],
               "the player offers a wide card and the timer and calendar their live tile")
        suite.expect(NotchModule.clipboard.homeSizes == [.icon]
               && Set(NotchModule.allCases.filter { $0.homeSizes != [.icon] }) == [.music, .timer, .calendar],
               "a page no view draws at another size offers only its icon")
        suite.expect(NotchHomeTileSize.icon.span(columns: 4) == 1 && NotchHomeTileSize.live.span(columns: 4) == 1
               && NotchHomeTileSize.wide.span(columns: 4) == 4 && NotchHomeTileSize.wide.span(columns: 0) == 1,
               "a wide card spans the row and every other size one column")
    }

    private static func storage(_ suite: TestSuite) {
        suite.expect(NotchSupport.homeTileSizes("music:wide,timer:live") == [.music: .wide, .timer: .live],
                     "stored pairs read as each page's size")
        suite.expect(NotchSupport.homeTileSizes(nil).isEmpty && NotchSupport.homeTileSizes("").isEmpty,
                     "nothing stored leaves every page an icon")
        suite.expect(NotchSupport.homeTileSizes("music:live").isEmpty && NotchSupport.homeTileSizes("clipboard:wide").isEmpty,
                     "a size the page does not offer is ignored")
        suite.expect(NotchSupport.homeTileSizes("bogus:wide").isEmpty && NotchSupport.homeTileSizes("music:huge").isEmpty,
                     "an unknown page or size is ignored")
        suite.expect(NotchSupport.homeTileSizes("music").isEmpty && NotchSupport.homeTileSizes("music:wide:live").isEmpty
               && NotchSupport.homeTileSizes(":wide").isEmpty && NotchSupport.homeTileSizes("music:").isEmpty,
               "an entry without exactly a page and a size is ignored")
        suite.expect(NotchSupport.homeTileSizes("files:icon,music:icon").isEmpty,
                     "an icon is never stored, being what a page shows without an entry")
        suite.expect(NotchSupport.homeTileSizes(" music : wide , timer:live ,, ") == [.music: .wide, .timer: .live],
                     "spaces around entries and empty entries do no harm")
        suite.expect(NotchSupport.homeTileSizes("timer:live,timer:icon") == [.timer: .live]
               && NotchSupport.homeTileSizes("music:wide,music:live") == [.music: .wide],
               "the first entry for a page wins")
        suite.expect(NotchSupport.homeTileSizes("music:live,music:wide") == [.music: .wide],
               "an entry that cannot apply does not shadow a later one that can")

        suite.expect(NotchSupport.homeTileSizesValue([.timer: .live, .music: .wide]) == "music:wide,timer:live"
               && NotchSupport.homeTileSizesValue([.timer: .live, .calendar: .live, .music: .wide])
                    == "music:wide,calendar:live,timer:live",
               "stored pairs follow the pages' own order whatever the dictionary's")
        suite.expect(NotchSupport.homeTileSizesValue([:]).isEmpty
               && NotchSupport.homeTileSizesValue([.clipboard: .icon, .music: .icon]).isEmpty,
               "icons are left out of what is stored")
        suite.expect(NotchSupport.homeTileSizesValue([.music: .live, .clipboard: .wide, .timer: .live]) == "timer:live",
               "sizes a page does not offer are left out of what is stored")
        for value in ["", "music:wide", "calendar:live", "music:wide,calendar:live,timer:live"] {
            suite.expect(NotchSupport.homeTileSizesValue(NotchSupport.homeTileSizes(value)) == value,
                         "\"\(value)\" survives being read and written back")
        }
        let sizes: [NotchModule: NotchHomeTileSize] = [.music: .wide, .timer: .live]
        suite.expect(NotchSupport.homeTileSizes(NotchSupport.homeTileSizesValue(sizes)) == sizes,
                     "written sizes read back as they were")

        let modules: [NotchModule] = [.music, .controls, .timer, .clipboard]
        suite.expect(NotchSupport.homeItems(modules, sizes: [:]) == modules.map { NotchHomeItem(module: $0, size: .icon) },
                     "without sizes Home lists every page as an icon in order")
        suite.expect(NotchSupport.homeItems(modules, sizes: [.music: .wide, .timer: .live, .clipboard: .live])
                        == [NotchHomeItem(module: .music, size: .wide), NotchHomeItem(module: .controls, size: .icon),
                            NotchHomeItem(module: .timer, size: .live), NotchHomeItem(module: .clipboard, size: .icon)],
               "Home keeps the order it is given and falls back to the icon where a page does not offer the size")
        suite.expect(NotchSupport.homeItems(modules, sizes: [.timer: .wide]).last(where: { $0.module == .timer })?.size == .icon,
                     "a size the page does not offer shows as an icon")
        suite.expect(NotchSupport.homeItems([], sizes: [.music: .wide]).isEmpty, "no pages leave Home empty")
    }

    private static func rowLayout(_ suite: TestSuite) {
        let all = NotchModule.allCases
        for columns in 3...5 {
            let expected = stride(from: 0, to: all.count, by: columns).map { start in
                items(Array(all[start..<min(start + columns, all.count)]))
            }
            suite.expect(NotchHomeLayout.rows(items(all), columns: columns) == expected,
                         "all icons fill the rows left to right like the gallery at \(columns) columns")
            suite.expect((1...all.count).allSatisfy {
                NotchHomeLayout.rows(items(Array(all.prefix($0))), columns: columns).count
                    == NotchSectionPaging.rows(count: $0, columns: columns)
            }, "all icons take as many rows as the gallery pages at \(columns) columns")
        }

        let mixed = items([.controls, .mixer, .music, .clipboard, .captures], wide: [.music])
        suite.expect(NotchHomeLayout.rows(mixed, columns: 4)
                        == [items([.controls, .mixer, .clipboard, .captures]), items([.music], wide: [.music])],
               "a wide card takes its own row and the icons after it fill the room before it")
        suite.expect(NotchHomeLayout.rows(items([.music, .controls, .mixer], wide: [.music]), columns: 4)
                        == [items([.music], wide: [.music]), items([.controls, .mixer])],
               "a wide card first sits alone in the first row")
        suite.expect(NotchHomeLayout.rows(items([.music, .controls, .mixer, .clipboard, .captures], wide: [.music]), columns: 3)
                        == [items([.music], wide: [.music]), items([.controls, .mixer, .clipboard]), items([.captures])],
               "icons after a wide card keep their order in the rows below it")
        suite.expect(NotchHomeLayout.rows(items([.controls, .music, .mixer, .system, .captures, .clipboard], wide: [.music]),
                                          columns: 3)
                        == [items([.controls, .mixer, .system]), items([.music], wide: [.music]), items([.captures, .clipboard])],
               "an icon fills a hole above a wide card only while the row has room")
        suite.expect(NotchHomeLayout.rows([NotchHomeItem(module: .timer, size: .live), NotchHomeItem(module: .music, size: .wide)],
                                          columns: 2)
                        == [[NotchHomeItem(module: .timer, size: .live)], [NotchHomeItem(module: .music, size: .wide)]],
               "a live tile takes one column")

        let single = items([.controls, .mixer, .music], wide: [.music])
        for columns in [1, 0, -3] {
            suite.expect(NotchHomeLayout.rows(single, columns: columns) == single.map { [$0] },
                         "\(columns) columns clamp to one item per row")
        }
        suite.expect(NotchHomeLayout.rows([], columns: 4).isEmpty, "no items make no rows")

        let rows = NotchHomeLayout.rows(mixed, columns: 4)
        suite.expect(NotchHomeLayout.row(of: .controls, in: rows) == 0 && NotchHomeLayout.row(of: .captures, in: rows) == 0
               && NotchHomeLayout.row(of: .music, in: rows) == 1,
               "a page is found in the row it landed in")
        suite.expect(NotchHomeLayout.row(of: .files, in: rows) == nil && NotchHomeLayout.row(of: .music, in: []) == nil,
                     "a page that is not on Home has no row")
    }

    private static func arrowKeys(_ suite: TestSuite) {
        let rows = NotchHomeLayout.rows(items([.controls, .mixer, .music, .clipboard, .captures], wide: [.music]), columns: 4)
        func move(_ module: NotchModule?, _ direction: QuickToolsSupport.GridDirection) -> NotchModule? {
            NotchHomeLayout.adjacent(to: module, in: rows, columns: 4, direction: direction)
        }
        suite.expect(move(.controls, .right) == .mixer && move(.mixer, .right) == .clipboard && move(.mixer, .left) == .controls,
                     "left and right step along the row")
        suite.expect(move(.controls, .left) == .controls && move(.captures, .right) == .captures
               && move(.music, .left) == .music && move(.music, .right) == .music,
               "left and right stop at the ends of a row instead of wrapping")
        suite.expect(move(.controls, .down) == .music && move(.captures, .down) == .music,
                     "down from an icon onto a wide card lands on it")
        suite.expect(move(.music, .up) == .mixer,
                     "up from a wide card lands on the leftmost of the two icons nearest its centre")
        suite.expect(move(.controls, .up) == .controls && move(.music, .down) == .music,
                     "up and down stop at the first and last row")
        suite.expect(move(nil, .down) == .music && move(nil, .right) == .mixer && move(nil, .left) == .controls,
                     "with nothing highlighted an arrow moves from the first item")
        suite.expect(move(.files, .right) == .mixer,
                     "a highlight that is no longer on Home moves from the first item")
        suite.expect(NotchHomeLayout.adjacent(to: .controls, in: [], columns: 4, direction: .down) == nil
               && NotchHomeLayout.adjacent(to: nil, in: [], columns: 4, direction: .right) == nil,
               "an empty Home has nowhere to go")

        // Wide card over a row that does not fill the width: down lands under its centre.
        let uneven = NotchHomeLayout.rows(items([.music, .controls, .mixer, .clipboard], wide: [.music]), columns: 5)
        func step(_ module: NotchModule?, _ direction: QuickToolsSupport.GridDirection) -> NotchModule? {
            NotchHomeLayout.adjacent(to: module, in: uneven, columns: 5, direction: direction)
        }
        suite.expect(uneven.count == 2 && step(.music, .down) == .clipboard
               && step(.controls, .up) == .music && step(.clipboard, .up) == .music,
               "a wide card leads down to the icon under its centre and every icon below it leads back up")

        // A plain grid moves exactly as the gallery always has, short last
        // rows and a first press with nothing highlighted included.
        let directions: [QuickToolsSupport.GridDirection] = [.left, .right, .up, .down]
        for count in [1, 5, 7, 12, 14, NotchModule.allCases.count] {
            let order = Array(NotchModule.allCases.prefix(count))
            for columns in [3, 4, 5] {
                let rows = NotchHomeLayout.rows(items(order), columns: columns)
                for direction in directions {
                    for (index, module) in order.enumerated() {
                        let expected = order[QuickToolsSupport.gridIndex(after: index, count: order.count, columns: columns,
                                                                         direction: direction)]
                        suite.expect(NotchHomeLayout.adjacent(to: module, in: rows, columns: columns, direction: direction) == expected,
                                     "arrows over an all-icon Home move like the old gallery: \(count) pages, \(columns) columns")
                    }
                    let fromFirst = order[QuickToolsSupport.gridIndex(after: 0, count: order.count, columns: columns,
                                                                      direction: direction)]
                    suite.expect(NotchHomeLayout.adjacent(to: nil, in: rows, columns: columns, direction: direction) == fromFirst,
                                 "a first arrow over an all-icon Home moves from the first page, as the old gallery did")
                }
            }
        }
    }

    private static func moveToStart(_ suite: TestSuite) {
        let ids = NotchModule.allCases.map(\.rawValue)
        suite.expect(NotchSupport.movingToStart(.music, order: "")
                        == (["music"] + ids.filter { $0 != "music" }).joined(separator: ","),
               "with no stored order the page leads the pages' own order")
        suite.expect(NotchSupport.movingToStart(.music, order: "controls,legacy,mixer,music,clipboard")
                        == "music,controls,legacy,mixer,clipboard",
               "the other stored ids keep their places, unknown ones too")
        suite.expect(NotchSupport.movingToStart(.music, order: "music,controls,mixer") == "music,controls,mixer",
                     "a page already first leaves the order as it was")
        suite.expect(NotchSupport.movingToStart(.music, order: "controls,music,mixer,music") == "music,controls,mixer",
                     "a page stored twice is kept once, first")
        suite.expect(NotchSupport.movingToStart(.timer, order: "controls,mixer") == "timer,controls,mixer",
                     "a page missing from the stored order is put first")
        suite.expect(NotchSupport.movingToStart(.music, order: ",controls,,mixer,") == "music,controls,mixer",
                     "empty entries are dropped as the pages' order drops them")
        suite.expect(NotchSupport.movingToStart(.music, order: "music") == "music",
                     "a stored order of just that page stays as it is")
    }

    private static func galleryGeometry(_ suite: TestSuite) {
        let geometry = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1512, height: 982), safeAreaTop: 32, cameraWidth: 210)
        let fitting = NotchLayout.railRows(count: 99, perRow: 1, rowHeight: NotchLayout.sectionTileHeight,
                                           spacing: NotchLayout.sectionSpacing, height: geometry.pageBudget)
        suite.expect(fitting > 1 && geometry.sectionRows(rowCount: 99) == fitting && geometry.sectionRows(rowCount: fitting + 1) == fitting
               && geometry.sectionRows(rowCount: fitting) == fitting && geometry.sectionRows(rowCount: 1) == 1,
               "the visible rows cap at what the page budget fits")
        suite.expect((0...40).allSatisfy { count in
            geometry.sectionRows(rowCount: NotchSectionPaging.rows(count: count, columns: geometry.sectionColumns))
                == NotchLayout.railRows(count: count, perRow: geometry.sectionColumns, rowHeight: NotchLayout.sectionTileHeight,
                                        spacing: NotchLayout.sectionSpacing, height: geometry.pageBudget)
        }, "counting rows instead of tiles gives the gallery the visible rows it always had")
        suite.expect(geometry.contentSize(for: geometry.sectionPickerSize(rowCount: 0)).height == NotchLayout.emptyHeight,
                     "a gallery without rows is the empty height")
        suite.expect(geometry.contentSize(for: geometry.sectionPickerSize(rowCount: 1)).height == NotchLayout.sectionTileHeight
               && geometry.sectionPickerSize(rowCount: 99).height == geometry.sectionPickerSize(rowCount: fitting).height
               && geometry.sectionPickerSize(rowCount: 1).height < geometry.sectionPickerSize(rowCount: 2).height,
               "a gallery takes just its rows up to what the page fits")
    }
}
