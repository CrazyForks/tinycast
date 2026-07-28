import Foundation

enum CalcToken: Equatable, Sendable {
    case number(Double)
    /// An attached thousands suffix (`10k` / `2.5K`), kept distinct so a lone shorthand still earns a calculator card.
    case compactNumber(Double)
    /// Radix-prefixed integer literal (0xff / 0b1010 / 0o777), kept exact for base conversion.
    case intLiteral(UInt64, radix: Int)
    /// Lowercased word (function, constant, unit, or connector); `²`/`³` fold to "2"/"3" so `m²` and `m2` match, while `°` is kept.
    case ident(String)
    case op(Character)  // + - * / ^ ! % ( )
    case arrow  // -> or →
}

enum CalcTokenizer {
    /// nil on any character that can't be calculator input — the caller treats that as "not a calculation", never an error.
    static func tokenize(_ input: String) -> [CalcToken]? {
        let chars = Array(input)
        var tokens: [CalcToken] = []
        var i = 0

        func isDigit(_ ch: Character) -> Bool { ch.isASCII && ch.isNumber }

        while i < chars.count {
            let ch = chars[i]
            if ch.isWhitespace {
                i += 1
                continue
            }

            // Radix literals: 0x… / 0b… / 0o… — needs ≥1 digit after the prefix, else fall through so "0" parses as a plain number.
            if ch == "0", i + 2 < chars.count,
                let radix = ["x": 16, "b": 2, "o": 8][String(chars[i + 1]).lowercased()]
            {
                let start = i + 2
                var end = start
                while end < chars.count, chars[end].isHexDigit { end += 1 }
                if end > start, let value = UInt64(String(chars[start..<end]), radix: radix) {
                    tokens.append(.intLiteral(value, radix: radix))
                    i = end
                    continue
                }
            }

            if isDigit(ch) || (ch == "." && i + 1 < chars.count && isDigit(chars[i + 1])) {
                var text = ""
                var seenDot = false
                while i < chars.count {
                    let c = chars[i]
                    if isDigit(c) {
                        text.append(c)
                    } else if c == "," && i + 1 < chars.count && isDigit(chars[i + 1]) {
                        // grouping separator between digits — skip
                    } else if c == "." && !seenDot {
                        seenDot = true
                        text.append(c)
                    } else {
                        break
                    }
                    i += 1
                }
                // Scientific notation, but only with digits behind the exponent so `2e` stays 2 · e.
                var shorthand = false
                if i < chars.count, chars[i] == "e" || chars[i] == "E" {
                    var start = i + 1
                    if start < chars.count, chars[start] == "+" || chars[start] == "-" { start += 1 }
                    if start < chars.count, isDigit(chars[start]) {
                        var end = start
                        while end < chars.count, isDigit(chars[end]) { end += 1 }
                        text += String(chars[i..<end])
                        i = end
                        shorthand = true
                    }
                }
                guard let value = Double(text) else { return nil }
                // Attached multiplier (`10k`, `2.5mn`); whitespace keeps Kelvin explicit, and `10kg` remains a unit literal.
                if let multiplier = compactMultiplier(chars, i) {
                    tokens.append(.compactNumber(value * multiplier.factor))
                    i += multiplier.length
                } else {
                    // Shorthand earns a card on its own, since echoing the expanded number is the useful answer.
                    tokens.append(shorthand ? .compactNumber(value) : .number(value))
                }
                continue
            }

            if ch.isLetter || ch == "°" {
                // Split an attached currency prefix (`USD1K`) before the generic ident scanner absorbs its digits.
                if ch.isLetter {
                    var letterEnd = i
                    while letterEnd < chars.count, chars[letterEnd].isLetter { letterEnd += 1 }
                    if letterEnd < chars.count, isDigit(chars[letterEnd]) {
                        let prefix = String(chars[i..<letterEnd]).lowercased()
                        if CalcUnits.byName[prefix] == nil, CalcCurrency.byName[prefix] != nil {
                            tokens.append(.ident(prefix))
                            i = letterEnd
                            continue
                        }
                    }
                }
                var text = ""
                while i < chars.count {
                    let c = chars[i]
                    if c.isLetter || c == "°" || isDigit(c) {
                        text.append(c)
                    } else if c == "²" {
                        text.append("2")
                    } else if c == "³" {
                        text.append("3")
                    } else {
                        break
                    }
                    i += 1
                }
                tokens.append(.ident(text.lowercased()))
                continue
            }

            // Currency signs are punctuation, not letters: fold each to its ISO code so `€20 to gbp` tokenizes exactly like `20 eur to gbp`.
            if let code = CurrencyData.signs[ch] {
                tokens.append(.ident(code))
                i += 1
                continue
            }

            switch ch {
            // A `,` between digits was already consumed as a grouping separator above; here it can only be an argument separator.
            case "+", "(", ")", "!", "%", "^", ",":
                tokens.append(.op(ch))
            case "*", "×":
                tokens.append(.op("*"))
            case "/", "÷":
                tokens.append(.op("/"))
            case "−":
                tokens.append(.op("-"))
            case "-":
                if i + 1 < chars.count, chars[i + 1] == ">" {
                    tokens.append(.arrow)
                    i += 1
                } else {
                    tokens.append(.op("-"))
                }
            case "→":
                tokens.append(.arrow)
            case "=":
                // Tolerate a trailing "=" ("2+2="); anywhere else it's not calculator input.
                guard i == chars.count - 1 else { return nil }
            default:
                return nil
            }
            i += 1
        }
        return normalize(tokens)
    }

    /// Written-out forms folded to the symbols the parsers already understand, so `square root of 625`
    /// and `4 power 6` need no grammar of their own. Longest phrase first — `to the power of` must win over `power`.
    private static let phrases: [(words: [String], tokens: [CalcToken])] = [
        (["to", "the", "power", "of"], [.op("^")]),
        (["square", "root", "of"], [.ident("sqrt")]),
        (["cube", "root", "of"], [.ident("cbrt")]),
        (["square", "root"], [.ident("sqrt")]),
        (["cube", "root"], [.ident("cbrt")]),
        (["power", "of"], [.op("^")]),
        (["power"], [.op("^")]),
        (["squared"], [.op("^"), .number(2)]),
        (["cubed"], [.op("^"), .number(3)]),
        (["percent"], [.op("%")]),
        (["divided", "by"], [.op("/")]),
        (["multiplied", "by"], [.op("*")]),
        (["times"], [.op("*")]),
        (["plus"], [.op("+")]),
        (["minus"], [.op("-")]),
    ]

    /// Multiplier words, folded into the preceding number: `5 million`.
    private static let multiplierWords: [String: Double] = [
        "million": 1e6, "billion": 1e9, "trillion": 1e12, "thousand": 1e3,
    ]

    private static func normalize(_ tokens: [CalcToken]) -> [CalcToken] {
        var output: [CalcToken] = []
        output.reserveCapacity(tokens.count)
        var index = 0
        while index < tokens.count {
            if case .ident(let name) = tokens[index], let factor = multiplierWords[name],
                let previous = output.last, let amount = numberValue(previous)
            {
                output[output.count - 1] = .compactNumber(amount * factor)
                index += 1
                continue
            }
            if let phrase = matchPhrase(tokens, at: index) {
                output.append(contentsOf: phrase.tokens)
                index += phrase.words.count
                continue
            }
            output.append(tokens[index])
            index += 1
        }
        return output
    }

    private static func matchPhrase(
        _ tokens: [CalcToken], at index: Int
    ) -> (words: [String], tokens: [CalcToken])? {
        for phrase in phrases where index + phrase.words.count <= tokens.count {
            let matches = phrase.words.enumerated().allSatisfy { offset, word in
                tokens[index + offset] == .ident(word)
            }
            if matches { return phrase }
        }
        return nil
    }

    private static func numberValue(_ token: CalcToken) -> Double? {
        switch token {
        case .number(let value), .compactNumber(let value):
            return value
        default:
            return nil
        }
    }

    /// Attached number multipliers. Only unambiguous spellings: bare `m` is already metres and bare `b` bytes.
    private static let multipliers: [(text: String, factor: Double)] = [
        ("mn", 1e6), ("bn", 1e9), ("tn", 1e12), ("k", 1e3),
    ]

    private static func compactMultiplier(
        _ chars: [Character], _ index: Int
    ) -> (factor: Double, length: Int)? {
        for multiplier in multipliers {
            let length = multiplier.text.count
            guard index + length <= chars.count,
                String(chars[index..<(index + length)]).lowercased() == multiplier.text,
                isCompactSuffix(chars, after: index + length)
            else { continue }
            // `k` is also Kelvin, so an explicit temperature target wins: `273.15K to C`.
            if multiplier.text == "k", isTemperatureConversion(chars, from: index + 1) { continue }
            return (multiplier.factor, length)
        }
        return nil
    }

    /// Whether a multiplier suffix really is one rather than the head of a unit: true at the end of the number, before a non-letter, or before a currency word (`1kUSD`).
    private static func isCompactSuffix(_ chars: [Character], after next: Int) -> Bool {
        guard next < chars.count else { return true }
        guard chars[next].isLetter else { return true }

        var end = next
        while end < chars.count, chars[end].isLetter { end += 1 }
        return CalcCurrency.byName[String(chars[next..<end]).lowercased()] != nil
    }

    /// True when the remainder reads as a conversion into a temperature unit, which keeps `k` as Kelvin.
    private static func isTemperatureConversion(_ chars: [Character], from index: Int) -> Bool {
        let remainder = String(chars[index...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        for connector in ["to", "in", "->", "→"] where remainder.hasPrefix(connector) {
            let target = remainder.dropFirst(connector.count)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if CalcUnits.byName[target]?.category == .temperature { return true }
        }
        return false
    }
}

/// Precedence-climbing evaluator over the token stream (evaluates while parsing, no AST), returning nil for anything malformed or non-finite.
enum CalcParser {
    static func evaluate(_ tokens: [CalcToken]) -> Double? {
        var parser = Parser(tokens: tokens)
        guard let result = parser.parseExpression(minBP: 0), parser.isAtEnd,
            result.effective.isFinite
        else { return nil }
        return result.effective
    }

    // Capture-free closures (not bare C function references) so every entry infers `@Sendable` under both language modes — the harness compiles this in Swift 5.
    fileprivate static let functions: [String: @Sendable (Double) -> Double] = [
        "sqrt": { sqrt($0) }, "cbrt": { cbrt($0) }, "log": { log10($0) }, "log2": { log2($0) },
        "ln": { log($0) }, "exp": { exp($0) }, "abs": { abs($0) }, "floor": { floor($0) },
        "ceil": { ceil($0) }, "round": { $0.rounded() }, "trunc": { $0.rounded(.towardZero) },
        "sign": { $0 == 0 ? 0 : ($0 < 0 ? -1 : 1) },
        "sin": { sin($0) }, "cos": { cos($0) }, "tan": { tan($0) },
        "asin": { asin($0) }, "acos": { acos($0) }, "atan": { atan($0) },
        "arcsin": { asin($0) }, "arccos": { acos($0) }, "arctan": { atan($0) },
        "sinh": { sinh($0) }, "cosh": { cosh($0) }, "tanh": { tanh($0) },
        "asinh": { asinh($0) }, "acosh": { acosh($0) }, "atanh": { atanh($0) },
        // Reciprocal trig: at a pole the division yields ±inf, which `evaluate`'s isFinite guard turns into a no-card.
        "cot": { 1 / tan($0) }, "sec": { 1 / cos($0) }, "csc": { 1 / sin($0) },
        "coth": { 1 / tanh($0) }, "sech": { 1 / cosh($0) }, "csch": { 1 / sinh($0) },
        "acot": { atan(1 / $0) }, "asec": { acos(1 / $0) }, "acsc": { asin(1 / $0) },
    ]

    /// Two-argument functions, comma-separated. `log(8, 2)` is log base 2, alongside the one-argument base-10 `log`.
    fileprivate static let binaryFunctions: [String: @Sendable (Double, Double) -> Double] = [
        "min": { Swift.min($0, $1) }, "max": { Swift.max($0, $1) },
        "mod": { fmod($0, $1) }, "pow": { pow($0, $1) },
        "log": { log($0) / log($1) },
    ]

    fileprivate static let constants: [String: Double] = [
        "pi": .pi, "π": .pi, "e": M_E, "tau": .pi * 2, "τ": .pi * 2, "phi": (1 + 5.squareRoot()) / 2,
    ]

    /// Factorial for non-negative integers; 170! is the last value representable as a Double.
    static func factorial(_ value: Double) -> Double? {
        guard value >= 0, value.rounded() == value, value <= 170 else { return nil }
        var result = 1.0
        var next = 2.0
        while next <= value {
            result *= next
            next += 1
        }
        return result
    }
}

private struct Parser {
    /// A value that may still be a "percent" (`20%`): additive ops treat it as a relative change, everything else as value/100.
    struct Value {
        var value: Double
        var isPercent = false
        var effective: Double { isPercent ? value / 100 : value }
    }

    let tokens: [CalcToken]
    var pos = 0

    init(tokens: [CalcToken]) { self.tokens = tokens }

    var isAtEnd: Bool { pos == tokens.count }
    private var current: CalcToken? { pos < tokens.count ? tokens[pos] : nil }

    // Binding powers: additive 10, multiplicative (incl. "of") 20, unary minus 25, power 30 (right-assoc), postfix ! % deg tightest.
    private static let unaryBP = 25

    mutating func parseExpression(minBP: Int) -> Value? {
        guard var lhs = parseOperand() else { return nil }
        while let (op, bp, rightBP) = peekBinary(), bp >= minBP {
            pos += 1
            guard let rhs = parseExpression(minBP: rightBP) else { return nil }
            guard let combined = apply(op, lhs, rhs) else { return nil }
            lhs = combined
        }
        return lhs
    }

    /// (operator, its binding power, minimum bp for its right operand).
    private func peekBinary() -> (Character, Int, Int)? {
        switch current {
        case .op(let op) where op == "+" || op == "-": return (op, 10, 11)
        case .op(let op) where op == "*" || op == "/": return (op, 20, 21)
        case .ident("of"): return ("*", 20, 21)
        // `%` is taken by the percent postfix, so modulo is spelled out. It never reaches here as an op token.
        case .ident("mod"): return ("%", 20, 21)
        case .op("^"): return ("^", 30, 30)  // right-associative: 2^3^2 = 512
        default: return nil
        }
    }

    private func apply(_ op: Character, _ lhs: Value, _ rhs: Value) -> Value? {
        let result: Double
        switch op {
        // `450 + 20%` reads as a relative change: 450 * 1.2. With a plain rhs it's ordinary math.
        case "+":
            result =
                rhs.isPercent
                ? lhs.effective * (1 + rhs.value / 100) : lhs.effective + rhs.effective
        case "-":
            result =
                rhs.isPercent
                ? lhs.effective * (1 - rhs.value / 100) : lhs.effective - rhs.effective
        case "*": result = lhs.effective * rhs.effective
        case "/": result = lhs.effective / rhs.effective
        case "^": result = pow(lhs.effective, rhs.effective)
        case "%": result = fmod(lhs.effective, rhs.effective)
        default: return nil
        }
        return Value(value: result)
    }

    /// One prefix item plus all its postfixes (`!`, `%`, `deg`) — postfixes bind tightest.
    private mutating func parseOperand() -> Value? {
        guard var value = parsePrefix() else { return nil }
        loop: while true {
            switch current {
            case .op("!"):
                guard !value.isPercent, let fact = CalcParser.factorial(value.value) else {
                    return nil
                }
                value = Value(value: fact)
            case .op("%"):
                guard !value.isPercent else { return nil }
                value.isPercent = true
            case .ident("deg"):
                guard !value.isPercent else { return nil }
                value = Value(value: value.value * .pi / 180)
            default:
                break loop
            }
            pos += 1
        }
        return value
    }

    private mutating func parsePrefix() -> Value? {
        switch current {
        case .number(let n):
            pos += 1
            return Value(value: n)
        case .compactNumber(let n):
            pos += 1
            return Value(value: n)
        case .intLiteral(let n, _):
            pos += 1
            return Value(value: Double(n))
        case .op("-"):
            pos += 1
            guard let operand = parseExpression(minBP: Self.unaryBP) else { return nil }
            return Value(value: -operand.effective)
        case .op("+"):
            pos += 1
            return parseExpression(minBP: Self.unaryBP)
        case .op("("):
            pos += 1
            guard let inner = parseExpression(minBP: 0), case .op(")") = current else { return nil }
            pos += 1
            return inner
        case .ident(let name):
            if let constant = CalcParser.constants[name] {
                pos += 1
                return Value(value: constant)
            }
            let unary = CalcParser.functions[name]
            let binary = CalcParser.binaryFunctions[name]
            guard unary != nil || binary != nil else { return nil }
            pos += 1

            guard case .op("(") = current else {
                // Bare application: `sqrt 64`, `sin 30deg` — the argument is one operand, so `sqrt 64 + 36` is sqrt(64) + 36.
                guard let unary, let argument = parseOperand() else { return nil }
                return Value(value: unary(argument.effective))
            }
            pos += 1
            guard let first = parseExpression(minBP: 0) else { return nil }
            // A comma picks the two-argument reading, so `log` serves both base 10 and an explicit base.
            if case .op(",") = current, let binary {
                pos += 1
                guard let second = parseExpression(minBP: 0), case .op(")") = current else {
                    return nil
                }
                pos += 1
                return Value(value: binary(first.effective, second.effective))
            }
            guard case .op(")") = current, let unary else { return nil }
            pos += 1
            return Value(value: unary(first.effective))
        default:
            return nil
        }
    }
}
