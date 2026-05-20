import SwiftUI

public struct SegmentedBar: View {
    public let percent: Double
    public var cells: Int = 10
    public var cellHeight: CGFloat = 8

    public init(percent: Double, cells: Int = 10, cellHeight: CGFloat = 8) {
        self.percent = percent
        self.cells = cells
        self.cellHeight = cellHeight
    }

    private var fullCells: Int  { Int(percent / 10.0) }
    private var partial: Double { (percent / 10.0) - Double(fullCells) }

    public var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<cells, id: \.self) { i in
                if i < fullCells {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Self.color(for: percent))
                        .frame(maxWidth: .infinity)
                        .frame(height: cellHeight)
                } else if i == fullCells && partial > 0 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.12))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Self.color(for: percent))
                                .frame(width: geo.size.width * partial)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: cellHeight)
                } else {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.12))
                        .frame(maxWidth: .infinity)
                        .frame(height: cellHeight)
                }
            }
        }
    }

    public static func color(for percent: Double) -> Color {
        switch percent {
        case ..<40:  return Color(red: 0.82, green: 0.44, blue: 0.30)
        case ..<65:  return Color(red: 0.95, green: 0.75, blue: 0.20)
        case ..<85:  return Color(red: 0.95, green: 0.50, blue: 0.10)
        default:     return Color(red: 0.90, green: 0.20, blue: 0.15)
        }
    }
}
