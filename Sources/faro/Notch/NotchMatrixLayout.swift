// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Daniel Pulgarín

import SwiftUI

private struct NotchColumnSpanKey: LayoutValueKey { static let defaultValue = 1 }
private struct NotchRowSpanKey: LayoutValueKey { static let defaultValue = 1 }

extension View {
    func notchMatrixSpan(columns: Int, rows: Int) -> some View {
        layoutValue(key: NotchColumnSpanKey.self, value: min(max(columns, 1), 3))
            .layoutValue(key: NotchRowSpanKey.self, value: min(max(rows, 1), 2))
    }
}

/// Matriz compacta de tres columnas. Busca el primer hueco disponible para cada widget, por lo que
/// dos widgets de una fila pueden apilarse junto a otro de dos filas sin heredar su altura.
struct NotchMatrixLayout: Layout {
    var rowHeight: CGFloat
    var spacing: CGFloat

    private struct Cell {
        var index: Int
        var column: Int
        var row: Int
        var columns: Int
        var rows: Int
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 520
        let result = arrange(subviews)
        let height = result.rows == 0 ? 0 : CGFloat(result.rows) * rowHeight + CGFloat(result.rows - 1) * spacing
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(subviews)
        let cellWidth = max((bounds.width - spacing * 2) / 3, 1)
        for cell in result.cells {
            let width = cellWidth * CGFloat(cell.columns) + spacing * CGFloat(cell.columns - 1)
            let height = rowHeight * CGFloat(cell.rows) + spacing * CGFloat(cell.rows - 1)
            let point = CGPoint(x: bounds.minX + CGFloat(cell.column) * (cellWidth + spacing),
                                y: bounds.minY + CGFloat(cell.row) * (rowHeight + spacing))
            subviews[cell.index].place(at: point, anchor: .topLeading,
                                       proposal: ProposedViewSize(width: width, height: height))
        }
    }

    private func arrange(_ subviews: Subviews) -> (cells: [Cell], rows: Int) {
        var occupied: [[Bool]] = []
        var cells: [Cell] = []

        func fits(row: Int, column: Int, columns: Int, rows: Int) -> Bool {
            for y in row..<(row + rows) {
                if y >= occupied.count { continue }
                for x in column..<(column + columns) where occupied[y][x] { return false }
            }
            return true
        }

        for index in subviews.indices {
            let columnSpan = min(max(subviews[index][NotchColumnSpanKey.self], 1), 3)
            let rowSpan = min(max(subviews[index][NotchRowSpanKey.self], 1), 2)
            var targetRow = 0
            var targetColumn = 0
            var found = false
            while !found {
                for column in 0...(3 - columnSpan) where fits(row: targetRow, column: column, columns: columnSpan, rows: rowSpan) {
                    targetColumn = column; found = true; break
                }
                if !found { targetRow += 1 }
            }
            while occupied.count < targetRow + rowSpan { occupied.append([Bool](repeating: false, count: 3)) }
            for y in targetRow..<(targetRow + rowSpan) {
                for x in targetColumn..<(targetColumn + columnSpan) { occupied[y][x] = true }
            }
            cells.append(Cell(index: index, column: targetColumn, row: targetRow, columns: columnSpan, rows: rowSpan))
        }

        // Aprovecha columnas libres a la derecha sin cambiar la preferencia guardada del widget.
        for index in cells.indices {
            var extra = 0
            while cells[index].column + cells[index].columns + extra < 3 {
                let x = cells[index].column + cells[index].columns + extra
                let clear = (cells[index].row..<(cells[index].row + cells[index].rows)).allSatisfy { !occupied[$0][x] }
                if !clear { break }
                extra += 1
            }
            if extra > 0 {
                for y in cells[index].row..<(cells[index].row + cells[index].rows) {
                    for x in (cells[index].column + cells[index].columns)..<(cells[index].column + cells[index].columns + extra) {
                        occupied[y][x] = true
                    }
                }
                cells[index].columns += extra
            }
        }
        return (cells, occupied.count)
    }
}
