import SwiftUI
import Charts

struct MonthlyBarChart: View {
    let data: [(month: Date, count: Int)]

    /// Pads the domain by a month on each side so a single month of data doesn't
    /// stretch to fill (and dominate) the whole plot width.
    private var domain: ClosedRange<Date> {
        let calendar = Calendar.current
        let months = data.map(\.month)
        let minMonth = months.min() ?? .now
        let maxMonth = months.max() ?? .now
        let start = calendar.date(byAdding: .month, value: -1, to: minMonth) ?? minMonth
        let end = calendar.date(byAdding: .month, value: 1, to: maxMonth) ?? maxMonth
        return start...end
    }

    var body: some View {
        Chart(data, id: \.month) { point in
            BarMark(
                x: .value("Month", point.month, unit: .month),
                y: .value("Count", point.count)
            )
            .foregroundStyle(LJTheme.accent)
        }
        .chartXScale(domain: domain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).year(.twoDigits))
                    .foregroundStyle(LJTheme.textSecondary)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisValueLabel().foregroundStyle(LJTheme.textSecondary)
                AxisGridLine().foregroundStyle(LJTheme.surface)
            }
        }
        .frame(height: 140)
    }
}

struct CollectionGrowthChart: View {
    let data: [(month: Date, total: Int)]

    var body: some View {
        Chart(data, id: \.month) { point in
            AreaMark(
                x: .value("Month", point.month, unit: .month),
                y: .value("Total", point.total)
            )
            .interpolationMethod(.stepEnd)
            .foregroundStyle(LJTheme.accent.opacity(0.2))

            LineMark(
                x: .value("Month", point.month, unit: .month),
                y: .value("Total", point.total)
            )
            .interpolationMethod(.stepEnd)
            .foregroundStyle(LJTheme.accent)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                AxisValueLabel(format: .dateTime.year())
                    .foregroundStyle(LJTheme.textSecondary)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisValueLabel().foregroundStyle(LJTheme.textSecondary)
                AxisGridLine().foregroundStyle(LJTheme.surface)
            }
        }
        .frame(height: 140)
    }
}

struct GenreBarChart: View {
    let data: [(genre: String, count: Int)]

    private var topGenres: [(genre: String, count: Int)] {
        Array(data.prefix(15))
    }

    var body: some View {
        Chart(topGenres, id: \.genre) { point in
            BarMark(
                x: .value("Count", point.count),
                y: .value("Genre", point.genre)
            )
            .foregroundStyle(LJTheme.accent)
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel().foregroundStyle(LJTheme.textSecondary)
                AxisGridLine().foregroundStyle(LJTheme.surface)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisValueLabel().foregroundStyle(LJTheme.textPrimary)
            }
        }
        .frame(height: CGFloat(topGenres.count) * 30 + 20)
    }
}

struct FormatPieChart: View {
    let data: [(format: String, count: Int)]

    /// Shades of the single accent color, darkest-to-lightest by rank, rather than an
    /// arbitrary multi-color palette — matches every other chart in the app.
    private func sliceColor(for index: Int) -> Color {
        LJTheme.accent.opacity(max(0.25, 1.0 - Double(index) * 0.18))
    }

    var body: some View {
        HStack(spacing: LJTheme.Spacing.lg) {
            Chart(Array(data.enumerated()), id: \.offset) { index, point in
                SectorMark(
                    angle: .value("Count", point.count),
                    angularInset: 1.5
                )
                .cornerRadius(3)
                .foregroundStyle(sliceColor(for: index))
            }
            .frame(width: 120, height: 120)

            VStack(alignment: .leading, spacing: LJTheme.Spacing.sm) {
                ForEach(Array(data.enumerated()), id: \.offset) { index, point in
                    HStack(spacing: LJTheme.Spacing.sm) {
                        Circle()
                            .fill(sliceColor(for: index))
                            .frame(width: 10, height: 10)
                        Text(point.format)
                            .font(.subheadline)
                            .foregroundStyle(LJTheme.textPrimary)
                        Spacer()
                        Text("\(point.count)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(LJTheme.textSecondary)
                    }
                }
            }
        }
    }
}

struct RatingHistogramChart: View {
    let histogram: [Double: Int]

    private var data: [(stars: Double, count: Int)] {
        stride(from: 0.5, through: 5.0, by: 0.5).map { (stars: $0, count: histogram[$0] ?? 0) }
    }

    private func label(for stars: Double) -> String {
        stars.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f★", stars)
            : String(format: "%.1f★", stars)
    }

    var body: some View {
        Chart(data, id: \.stars) { point in
            BarMark(
                x: .value("Stars", label(for: point.stars)),
                y: .value("Count", point.count)
            )
            .foregroundStyle(LJTheme.accent)
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel().foregroundStyle(LJTheme.textSecondary)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisValueLabel().foregroundStyle(LJTheme.textSecondary)
                AxisGridLine().foregroundStyle(LJTheme.surface)
            }
        }
        .frame(height: 140)
    }
}

struct SplitProportionBar: View {
    let leftLabel: String
    let leftCount: Int
    let rightLabel: String
    let rightCount: Int

    private var total: Int { leftCount + rightCount }
    private var leftFraction: CGFloat {
        total > 0 ? CGFloat(leftCount) / CGFloat(total) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(LJTheme.accent)
                        .frame(width: geo.size.width * leftFraction)
                    Rectangle()
                        .fill(LJTheme.surface)
                }
            }
            .frame(height: 10)

            HStack {
                Text("\(leftLabel) (\(leftCount))")
                    .font(.caption)
                    .foregroundStyle(LJTheme.accent)
                Spacer()
                Text("\(rightLabel) (\(rightCount))")
                    .font(.caption)
                    .foregroundStyle(LJTheme.textSecondary)
            }
        }
    }
}
