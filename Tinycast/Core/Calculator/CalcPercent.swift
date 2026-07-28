import Foundation

/// Natural-language percentage phrasings the arithmetic parser doesn't cover: discounts (`20% off 500`),
/// markup and tips (`15% tip on 42`), ratios (`50 as % of 200`, `3 out of 4`, `ratio of 3 to 5`) and the two
/// distinct comparisons (`% change from 20 to 30`, `% difference between 20 and 30`). Foundation-only so
/// `Tools/calc-test.swift` compiles it with the rest of the engine. `X% of Y` and `Y + X%` already fall out
/// of the `of`/percent operators, so they aren't handled here; `percent` reaches us as `%` because the
/// tokenizer's normalization pass folds the word.
enum CalcPercent {
    static func evaluate(_ tokens: [CalcToken], query: String) -> CalcResult? {
        parseTip(tokens, query: query)
            ?? parseOff(tokens, query: query)
            ?? parseOn(tokens, query: query)
            ?? parseAsPercentOf(tokens, query: query)
            ?? parseOutOf(tokens, query: query)
            ?? parseChange(tokens, query: query)
            ?? parseDifference(tokens, query: query)
            ?? parseRatio(tokens, query: query)
    }

    /// `<pct>% off <value>` → the value reduced by pct percent (`20% off 500` → 400).
    private static func parseOff(_ tokens: [CalcToken], query: String) -> CalcResult? {
        guard let split = split(tokens, on: [.ident("off")], percentBefore: true),
            let scaled = scale(split, by: -1)
        else { return nil }
        return value(query, scaled)
    }

    /// `<pct>% on <value>` → the value increased by pct percent, i.e. a markup (`8% on 250` → 270).
    private static func parseOn(_ tokens: [CalcToken], query: String) -> CalcResult? {
        guard let split = split(tokens, on: [.ident("on")], percentBefore: true),
            let scaled = scale(split, by: 1)
        else { return nil }
        return value(query, scaled)
    }

    /// `<pct>% tip on <bill>` → the bill including the tip, since that's the number you actually pay.
    private static func parseTip(_ tokens: [CalcToken], query: String) -> CalcResult? {
        guard let split = split(tokens, on: [.ident("tip"), .ident("on")], percentBefore: true),
            let total = scale(split, by: 1)
        else { return nil }
        let tip = total - split.right
        return CalcResult(
            expression: "\(normalized(query))  (tip \(CalcFormatter.display(tip)))",
            sourceBadge: "Expression", targetBadge: "Total",
            payload: .value(
                display: CalcFormatter.display(total), copyText: CalcFormatter.copyText(total)))
    }

    /// `<x> as % of <y>` → x / y × 100, rendered as a percentage (`50 as % of 200` → 25%).
    private static func parseAsPercentOf(_ tokens: [CalcToken], query: String) -> CalcResult? {
        guard let split = split(tokens, on: [.ident("as"), .op("%"), .ident("of")]) else {
            return nil
        }
        return percent(query, ratio(split.left, split.right))
    }

    /// `<x> out of <y>` → the same ratio in the phrasing people use for scores (`3 out of 4` → 75%).
    private static func parseOutOf(_ tokens: [CalcToken], query: String) -> CalcResult? {
        guard let split = split(tokens, on: [.ident("out"), .ident("of")]) else { return nil }
        return percent(query, ratio(split.left, split.right))
    }

    /// `% change from <x> to <y>` → the signed change relative to x (`20 to 30` → 50%).
    private static func parseChange(_ tokens: [CalcToken], query: String) -> CalcResult? {
        guard
            let split = split(
                tokens, on: [.ident("from")], trailing: [.ident("to")], leading: [.ident("change")],
                percentBefore: true)
        else { return nil }
        return percent(query, ratio(split.right - split.left, split.left))
    }

    /// `% difference between <x> and <y>` → the symmetric difference, relative to the mean of the two.
    /// Deliberately a different formula from `% change`: 20 → 30 is a 50% change but a 40% difference.
    private static func parseDifference(_ tokens: [CalcToken], query: String) -> CalcResult? {
        guard
            let split = split(
                tokens, on: [.ident("between")], trailing: [.ident("and")],
                leading: [.ident("difference")], percentBefore: true)
        else { return nil }
        return percent(query, ratio(abs(split.right - split.left), (split.left + split.right) / 2))
    }

    /// `ratio of <x> to <y>` → the pair reduced by their greatest common divisor (`3 to 5` → `3:5`).
    private static func parseRatio(_ tokens: [CalcToken], query: String) -> CalcResult? {
        guard
            let split = split(
                tokens, on: [.ident("to")], leading: [.ident("ratio"), .ident("of")]),
            split.left.rounded() == split.left, split.right.rounded() == split.right,
            abs(split.left) < 1e15, abs(split.right) < 1e15,
            split.left != 0 || split.right != 0
        else { return nil }
        let divisor = gcd(Int(abs(split.left)), Int(abs(split.right)))
        guard divisor > 0 else { return nil }
        let text = "\(Int(split.left) / divisor):\(Int(split.right) / divisor)"
        return value(query, text)
    }

    // MARK: - Shared shape

    /// Splits `tokens` around a keyword run, evaluating both sides as ordinary arithmetic. `leading`
    /// anchors words the phrase must open with (`ratio of …`), `trailing` a second keyword that separates
    /// the two operands (`from … to …`), and `percentBefore` requires a `%` immediately ahead of the run.
    private static func split(
        _ tokens: [CalcToken], on keyword: [CalcToken], trailing: [CalcToken] = [],
        leading: [CalcToken] = [], percentBefore: Bool = false
    ) -> (left: Double, right: Double)? {
        guard let key = range(of: keyword, in: tokens) else { return nil }
        var operandStart = 0
        var operandEnd = key.lowerBound

        if leading.isEmpty {
            // `20% off 500`: the `%` sits right against the keyword, and the rate is everything before it.
            if percentBefore {
                guard operandEnd > 0, tokens[operandEnd - 1] == .op("%") else { return nil }
                operandEnd -= 1
            }
        } else {
            // `% change from …`: the `%` opens the phrase instead, ahead of the anchoring words.
            guard let anchor = range(of: leading, in: tokens),
                anchor.upperBound <= key.lowerBound,
                anchor.lowerBound == (percentBefore ? 1 : 0),
                !percentBefore || tokens.first == .op("%")
            else { return nil }
            operandStart = anchor.upperBound
        }

        let tail = Array(tokens[key.upperBound...])
        guard !tail.isEmpty, operandStart <= operandEnd else { return nil }
        let leftTokens = Array(tokens[operandStart..<operandEnd])

        if trailing.isEmpty {
            guard let left = CalcParser.evaluate(leftTokens),
                let right = CalcParser.evaluate(tail)
            else { return nil }
            return (left, right)
        }
        // `from x to y` / `between x and y`: both operands live behind the keyword.
        guard leftTokens.isEmpty, let separator = range(of: trailing, in: tail),
            let left = CalcParser.evaluate(Array(tail[0..<separator.lowerBound])),
            let right = CalcParser.evaluate(Array(tail[separator.upperBound...]))
        else { return nil }
        return (left, right)
    }

    private static func range(of keyword: [CalcToken], in tokens: [CalcToken]) -> Range<Int>? {
        guard !keyword.isEmpty, tokens.count >= keyword.count else { return nil }
        for start in 0...(tokens.count - keyword.count)
        where Array(tokens[start..<(start + keyword.count)]) == keyword {
            return start..<(start + keyword.count)
        }
        return nil
    }

    private static func scale(_ split: (left: Double, right: Double), by sign: Double) -> Double? {
        let output = split.right * (1 + sign * split.left / 100)
        return output.isFinite ? output : nil
    }

    private static func ratio(_ numerator: Double, _ denominator: Double) -> Double? {
        guard denominator != 0 else { return nil }
        let output = numerator / denominator * 100
        return output.isFinite ? output : nil
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int {
        var (a, b) = (a, b)
        while b != 0 { (a, b) = (b, a % b) }
        return a
    }

    private static func value(_ query: String, _ amount: Double) -> CalcResult {
        value(query, CalcFormatter.display(amount), copy: CalcFormatter.copyText(amount))
    }

    private static func percent(_ query: String, _ amount: Double?) -> CalcResult? {
        guard let amount else { return nil }
        return value(
            query, "\(CalcFormatter.display(amount))%", copy: "\(CalcFormatter.copyText(amount))%")
    }

    private static func value(_ query: String, _ text: String) -> CalcResult {
        value(query, text, copy: text)
    }

    private static func value(_ query: String, _ display: String, copy: String) -> CalcResult {
        CalcResult(
            expression: normalized(query),
            sourceBadge: "Expression",
            targetBadge: "Result",
            payload: .value(display: display, copyText: copy))
    }

    private static func normalized(_ query: String) -> String {
        query.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
