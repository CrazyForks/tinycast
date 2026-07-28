import Foundation

/// Physical length ↔ pixels at a given density: `2 inches in px at 72 ppi`, `96px to cm`. Pixels aren't a
/// `UnitDef` because they only mean a length once a density is named, so this is its own small path rather
/// than an eleventh `UnitCategory`. Foundation-only, like the rest of the engine.
enum CalcPixels {
    /// Points-per-inch when the query doesn't say. 72 is the typographic point, which is what a design tool means by "1 pt".
    private static let defaultDensity = 72.0
    private static let metersPerInch = 0.0254

    static func evaluate(_ tokens: [CalcToken], query: String) -> CalcResult? {
        var tokens = tokens
        var density = defaultDensity

        // Trailing `at <n> ppi` overrides the default, and is stripped before the conversion is read.
        if tokens.count >= 3, case .ident(let suffix) = tokens[tokens.count - 1],
            suffix == "ppi" || suffix == "dpi", tokens[tokens.count - 3] == .ident("at"),
            let named = numberValue(tokens[tokens.count - 2])
        {
            guard named > 0 else { return nil }
            density = named
            tokens.removeLast(3)
        }

        guard tokens.count >= 3, CalcUnits.isConnector(tokens[tokens.count - 2]),
            case .ident(let toName) = tokens[tokens.count - 1],
            case .ident(let fromName) = tokens[tokens.count - 3]
        else { return nil }

        let input: Double
        let valueTokens = Array(tokens[0..<(tokens.count - 3)])
        if valueTokens.isEmpty {
            input = 1
        } else if let value = CalcParser.evaluate(valueTokens) {
            input = value
        } else {
            return nil
        }

        if isPixels(toName), let from = lengthUnit(fromName) {
            let pixels = input * from.factor / metersPerInch * density
            return card(
                query, input: input, from: from.symbol, output: pixels, to: "px",
                sourceBadge: from.name, targetBadge: "Pixels", density: density)
        }
        if isPixels(fromName), let to = lengthUnit(toName) {
            let length = input / density * metersPerInch / to.factor
            return card(
                query, input: input, from: "px", output: length, to: to.symbol,
                sourceBadge: "Pixels", targetBadge: to.name, density: density)
        }
        return nil
    }

    private static func isPixels(_ name: String) -> Bool {
        name == "px" || name == "pixel" || name == "pixels"
    }

    private static func lengthUnit(_ name: String) -> UnitDef? {
        guard let unit = CalcUnits.byName[name], unit.category == .length else { return nil }
        return unit
    }

    private static func numberValue(_ token: CalcToken) -> Double? {
        switch token {
        case .number(let value), .compactNumber(let value):
            return value
        default:
            return nil
        }
    }

    private static func card(
        _ query: String, input: Double, from: String, output: Double, to: String,
        sourceBadge: String, targetBadge: String, density: Double
    ) -> CalcResult? {
        guard output.isFinite else { return nil }
        return CalcResult(
            expression: "\(CalcFormatter.display(input)) \(from) at \(CalcFormatter.display(density)) ppi",
            sourceBadge: sourceBadge,
            targetBadge: targetBadge,
            payload: .value(
                display: "\(CalcFormatter.display(output)) \(to)",
                copyText: "\(CalcFormatter.copyText(output)) \(to)"))
    }
}
