import Foundation

/// Shared by the gallery and the same card travelling back into the holder.
nonisolated struct LibraryArcGeometry {
    let size: CGSize
    static let headerHeight: CGFloat = 52
    static let footerHeight: CGFloat = 64
    var orbDiameter: CGFloat { min(max(0, size.height - 116) * 0.44, size.height < 505 ? 138 : size.width >= 650 ? 218 : 208) }
    var periodHeight: CGFloat { orbDiameter + 26 }
    var stageHeight: CGFloat { max(0, size.height - Self.headerHeight - Self.footerHeight - periodHeight) }
    var cardWidth: CGFloat { min(340, size.width * 0.73, max(0, stageHeight - 24) * 4 / 3) }
    var cardHeight: CGFloat { cardWidth * 0.75 }
    var pitch: CGFloat { cardWidth + 18 }
    var cardTop: CGFloat { Self.headerHeight + periodHeight + (stageHeight - cardHeight) / 2 }
}
