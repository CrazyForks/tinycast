// Standalone test for the calculator engine — compiles the *real* Foundation-only engine sources (no copy to sync): swiftc Tinycast/Core/Calculator/*.swift Tools/calc-test.swift -o /tmp/calc-test && /tmp/calc-test

import Foundation

@main
@MainActor
struct CalcTests {
    static var failures = 0
    static var passes = 0

    static func main() {
        // Arithmetic & precedence
        expectDisplay("2+2", "4")
        expectDisplay("5*7", "35")
        expectDisplay("100/4", "25")
        expectDisplay("2^10", "1,024")
        expectDisplay("2^3^2", "512")  // right-associative
        expectDisplay("(5+2)*3", "21")
        expectDisplay("5!", "120")
        expectDisplay("3!!", "720")  // (3!)! — chained postfix
        expectDisplay("-5+3", "-2")
        expectDisplay("-2^2", "-4")  // unary minus binds looser than ^
        expectDisplay("10/4", "2.5")
        expectDisplay("1/3", "0.3333333333")
        expectDisplay("2.5 * 4", "10")
        expectDisplay("1,000 + 234", "1,234")  // grouping commas accepted in input

        // Compact thousands suffix — attached `k` is a number suffix; spaced `k` remains Kelvin
        expectDisplay("10k", "10,000")
        expectCopy("10k", "10000")
        expectDisplay("2.5K", "2,500")
        expectDisplay("10k + 500", "10,500")
        expectDisplay("10k * 2", "20,000")
        expectBadges("10k", source: "Expression", target: "Result")

        // Functions
        expectDisplay("sqrt(64)", "8")
        expectDisplay("sqrt 64", "8")
        expectDisplay("sqrt 64 + 36", "44")  // bare arg is one operand: sqrt(64) + 36
        expectDisplay("log(1000)", "3")
        expectDisplay("ln(e)", "1")
        expectDisplay("sin(30deg)", "0.5")
        expectDisplay("cos(60deg)", "0.5")
        expectDisplay("tan(45deg)", "1")
        expectDisplay("sin(pi/2)", "1")
        expectDisplay("abs(-4)", "4")
        expectDisplay("floor(2.7)", "2")
        expectDisplay("ceil(2.1)", "3")
        expectDisplay("round(2.5)", "3")
        expectDisplay("SQRT(64)", "8")  // case-insensitive

        // Inverse, hyperbolic and reciprocal trig
        expectDisplay("asin(1)", "1.570796327")
        expectDisplay("acos(1)", "0")
        expectDisplay("atan(1)", "0.7853981634")
        expectDisplay("arcsin(0.5)", "0.5235987756")
        expectDisplay("sinh(1)", "1.175201194")
        expectDisplay("cosh(0)", "1")
        expectDisplay("tanh(0)", "0")
        expectDisplay("asinh(1)", "0.881373587")
        expectDisplay("atanh(0.5)", "0.5493061443")
        expectDisplay("cot(1)", "0.6420926159")
        expectDisplay("sec(0)", "1")
        expectDisplay("csc(1)", "1.188395106")
        expectDisplay("coth(1)", "1.313035285")
        expectDisplay("acot(1)", "0.7853981634")
        expectNil("asin(2)")  // out of domain — NaN stays a no-card
        expectNil("acosh(0.5)")

        // Remaining single-argument functions
        expectDisplay("cbrt(27)", "3")
        expectDisplay("log2(1024)", "10")
        expectDisplay("exp(1)", "2.718281828")
        expectDisplay("trunc(2.9)", "2")
        expectDisplay("sign(-5)", "-1")
        expectDisplay("sign(0)", "0")

        // Two-argument functions — a comma picks the binary reading, so `log` serves both bases
        expectDisplay("log(8, 2)", "3")  // ...while the unary `log(1000)` above stays base 10
        expectDisplay("min(3, 9)", "3")
        expectDisplay("max(3, 9)", "9")
        expectDisplay("pow(2, 10)", "1,024")
        expectDisplay("mod(10, 3)", "1")
        expectDisplay("10 mod 3", "1")
        expectNil("min(3)")  // no unary reading
        expectNil("min 3")
        // `min` and `sec` are also time-unit aliases; the unit path runs first and keeps them
        expectDisplay("90 min to hr", "1.5 hr")
        expectDisplay("90 sec to min", "1.5 min")
        expectDisplay("2 min + 30 sec", "150 s")
        expectNil("min")
        expectNil("sec")

        // Written-out operators
        expectDisplay("4 power 6", "4,096")
        expectDisplay("2 to the power of 10", "1,024")
        expectDisplay("square root of 625", "25")
        expectDisplay("square root 64", "8")
        expectDisplay("cube root of 27", "3")
        expectDisplay("5 squared", "25")
        expectDisplay("3 cubed", "27")
        expectDisplay("50 percent of 200", "100")
        expectDisplay("10 times 5", "50")
        expectDisplay("12 divided by 4", "3")
        expectDisplay("7 plus 3", "10")
        expectDisplay("9 minus 4", "5")
        expectDisplay("100 multiplied by 2", "200")
        // The words are common in app names, so alone or unpaired they must stay searches
        expectNil("power")
        expectNil("times")
        expectNil("plus")
        expectNil("minus")
        expectNil("percent")
        expectNil("new york times")
        expectNil("google plus")
        expectNil("powerpoint")
        expectNil("square")

        // Scientific notation, and the multiplier spellings that can't mean a unit
        expectDisplay("1e6", "1,000,000")
        expectDisplay("2e10", "20,000,000,000")
        expectDisplay("1.5e-3", "0.0015")
        expectDisplay("2e3 + 1", "2,001")
        expectNil("2e")  // no digits behind the exponent: still 2 · e
        expectDisplay("2.5mn", "2,500,000")
        expectDisplay("3bn", "3,000,000,000")
        expectDisplay("1tn", "1,000,000,000,000")
        expectDisplay("5 million", "5,000,000")
        expectDisplay("3 billion", "3,000,000,000")
        expectDisplay("1.5 thousand", "1,500")
        expectDisplay("10mn + 5mn", "15,000,000")
        expectDisplay("3 million dollars to eur", "2,760,000.00 EUR")
        expectNil("million")
        expectDisplay("5m", "16 feet 4.850393701 inches")  // bare `m` stays metres, never millions
        expectDisplay("5b", "40 bit")  // and bare `b` stays bytes

        // A lone radix literal names its own base
        expectBadges("0b1010", source: "Binary", target: "Decimal")
        expectBadges("0o777", source: "Octal", target: "Decimal")
        expectBadges("0xff", source: "Hexadecimal", target: "Decimal")

        // Constants
        expectDisplay("2*pi", "6.283185307")
        expectDisplay("π*2", "6.283185307")
        expectDisplay("e^2", "7.389056099")

        // Percent
        expectDisplay("20% of 450", "90")
        expectDisplay("450 + 20%", "540")
        expectDisplay("450 - 15%", "382.5")
        expectDisplay("20%", "0.2")

        // Discounts, markup and tips
        expectDisplay("8% on 250", "270")  // markup
        expectDisplay("15% tip on 42", "48.3")
        expectBadges("15% tip on 42", source: "Expression", target: "Total")
        expectExpression("15% tip on 42", "15% tip on 42  (tip 6.3)")

        // Ratios
        expectDisplay("50 as percent of 200", "25%")  // `percent` folds to `%`
        expectDisplay("3 out of 4", "75%")
        expectDisplay("1 out of 3", "33.33333333%")
        expectDisplay("ratio of 3 to 5", "3:5")
        expectDisplay("ratio of 10 to 4", "5:2")  // reduced by the gcd
        expectNil("ratio of 2.5 to 5")  // a ratio needs whole numbers

        // Change and difference are deliberately different formulas
        expectDisplay("% change from 20 to 30", "50%")
        expectDisplay("% change from 30 to 20", "-33.33333333%")
        expectDisplay("percent change from 20 to 30", "50%")
        expectDisplay("% difference between 20 and 30", "40%")
        expectDisplay("% difference between 30 and 20", "40%")  // symmetric, unlike change
        expectNil("% change from 0 to 10")  // no baseline to change from

        // Keywords alone, or with an operand missing, stay searches
        expectNil("tip")
        expectNil("ratio")
        expectNil("out of")
        expectNil("get out of jail")
        expectNil("% change")
        expectNil("ratio of")
        expectNil("10% off")
        expectNil("tip on 42")
        expectNil("% difference between 20")

        // Unit conversion — length / weight / temperature / time / area / volume / storage
        expectDisplay("10km to mi", "6.213711922 mi")
        expectDisplay("10 km in miles", "6.213711922 mi")
        expectDisplay("5ft in cm", "152.4 cm")
        expectDisplay("1 m to ft", "3.280839895 ft")
        expectDisplay("10 cm in in", "3.937007874 in")
        expectDisplay("10 in in cm", "25.4 cm")  // first "in" is the unit, second the connector
        expectDisplay("16 oz to lb", "1 lb")
        expectDisplay("2.2 lbs to kg", "0.997903214 kg")
        expectDisplay("100 C to F", "212 °F")
        expectDisplay("32F to C", "0 °C")
        expectDisplay("273.15K to C", "0 °C")  // attached Kelvin remains valid in a conversion
        expectDisplay("273.15 K to C", "0 °C")
        expectDisplay("10 k to c", "-263.15 °C")
        expectDisplay("0 F to C", "-17.77777778 °C")
        expectDisplay("300 K to C", "26.85 °C")
        expectDisplay("90min to hr", "1.5 hr")
        expectDisplay("2hr to min", "120 min")
        expectDisplay("1day to sec", "86,400 s")
        expectDisplay("1 week to hr", "168 hr")
        expectDisplay("2 acre to m2", "8,093.712845 m²")
        expectDisplay("1 m² to ft²", "10.76391042 ft²")
        expectDisplay("2L -> mL", "2,000 mL")
        expectDisplay("1 cup to tbsp", "16 tbsp")

        // Rate units written with a slash — the tokenizer rejoins them and looks the whole thing up
        expectDisplay("100 km/h to mph", "62.13711922 mph")
        expectDisplay("60 mph to km/h", "96.56064 km/h")
        expectDisplay("10 m/s to km/h", "36 km/h")  // and `m/s` is speed, never milliseconds
        expectDisplay("100 km / h to mph", "62.13711922 mph")  // spaced too
        expectDisplay("5 ft/s to m/s", "1.524 m/s")
        expectDisplay("100 Mb/s to Gbps", "0.1 Gbps")
        expectDisplay("1 gb/s to mbps", "1,000 Mbps")
        // Only when the joined name is a real unit; ordinary division must survive
        expectDisplay("10 kg / 2 kg", "5")
        expectDisplay("5kg / 500g", "10")
        expectDisplay("$10 / 4", "2.50 USD")
        expectDisplay("10 m / 2", "5 m")
        expectDisplay("1/2", "0.5")

        // Units written as several words
        expectDisplay("10 fl oz to ml", "295.7352956 mL")
        expectDisplay("1 fluid ounce to ml", "29.57352956 mL")
        expectDisplay("100 square feet to m2", "9.290304 m²")
        expectDisplay("5 sq ft to m2", "0.4645152 m²")
        expectDisplay("2 square meters to sqft", "21.52782083 ft²")

        // `timespan` spells a duration out; the ladder stops at weeks
        expectDisplay("145 mins to timespan", "2 hours 25 minutes")
        expectDisplay("90 s to timespan", "1 minute 30 seconds")
        expectDisplay("3661 s to timespan", "1 hour 1 minute 1 second")
        expectDisplay("10 days to timespan", "1 week 3 days")
        expectDisplay("2 hr to duration", "2 hours")
        expectDisplay("100000 s to timespan", "1 day 3 hours 46 minutes 40 seconds")
        expectDisplay("1.5 s to timespan", "1.5 seconds")  // a fraction survives as the only part
        expectDisplay("0.5 s to timespan", "500 milliseconds")
        expectBadges("145 mins to timespan", source: "Minutes", target: "Duration")
        expectNil("2 kg to timespan")  // time sources only
        expectNil("timespan")

        // Pixels need a density, so they get their own path rather than a unit category
        expectDisplay("2 inches in px at 72 ppi", "144 px")
        expectDisplay("2 inches in px", "144 px")  // 72 ppi by default
        expectDisplay("96px to inches", "1.333333333 in")
        expectDisplay("1 cm to px at 96 ppi", "37.79527559 px")
        expectDisplay("150 px to cm at 300 dpi", "1.27 cm")
        expectDisplay("10 mm in pixels at 300 ppi", "118.1102362 px")
        expectExpression("2 inches in px at 72 ppi", "2 in at 72 ppi")
        expectBadges("2 inches in px", source: "Inches", target: "Pixels")
        expectNil("2 inches in px at 0 ppi")
        expectNil("2 kg to px")
        expectNil("px")
        expectNil("pixelmator")
        expectDisplay("1 gal to L", "3.785411784 L")
        expectDisplay("1 GiB to MB", "1,073.741824 MB")
        expectDisplay("1 GB to MiB", "953.6743164 MiB")
        expectDisplay("8 bit to byte", "1 B")
        expectDisplay("2*5 km to mi", "6.213711922 mi")  // expression on the left side

        // Number bases
        expectDisplay("255 to hex", "0xFF")
        expectDisplay("255 to binary", "0b11111111")
        expectDisplay("0xff to decimal", "255")
        expectDisplay("0b1010 to decimal", "10")
        expectDisplay("255 to octal", "0o377")
        expectDisplay("0xff", "255")  // bare radix literal echoes decimal

        // Friendly category errors
        expectError("10kg to sec", "Cannot convert Weight to Time.")
        expectError("100 mL to km", "Cannot convert Volume to Length.")
        expectError("1 GB to hr", "Cannot convert Digital Storage to Time.")

        // Non-calculator input → no card
        expectNil("safari")
        expectNil("1password")
        expectNil("45")
        expectNil("3.14")
        expectNil("pi")
        expectNil("e")
        expectNil("10km to")  // half-typed conversion
        expectNil("10 to mi")
        expectDisplay("45+", "45")  // safe trailing operators keep the last complete result
        expectNil("sqrt()")
        expectNil("2.5!")  // factorial needs an integer
        expectNil("")

        // Formatting: display grouped, copyText plain
        expectDisplay("1234567*1", "1,234,567")
        expectCopy("1234567*1", "1234567")
        expectCopy("10km to mi", "6.213711922 mi")
        expectDisplay("-1234.5-0.25", "-1,234.75")

        // Card expression echo
        expectExpression("3*3", "3×3")
        expectExpression("10km to mi", "10 km")

        // Badges on explicit conversions
        expectBadges("10km to mi", source: "Kilometers", target: "Miles")
        expectBadges("100 C to F", source: "Celsius", target: "Fahrenheit")

        // Bare-unit auto-conversion (no connector)
        expectDisplay("1m", "3 feet 3.37007874 inches")
        expectExpression("1m", "1 m")
        expectBadges("1m", source: "Meters", target: "Feet")
        expectDisplay("1hr", "60 min")
        expectBadges("1hr", source: "Hours", target: "Minutes")
        expectDisplay("5ft", "1.524 m")
        expectDisplay("100g", "3.527396195 oz")
        expectDisplay("2*3 kg", "6 kg")  // an operator keeps the answer in the units written
        expectDisplay("20 celsius", "68 °F")
        expectDisplay("50cm", "19.68503937 in")
        // Ambiguous single-letter aliases stay app searches, not bare temperatures
        expectNil("5 k")
        expectNil("100 c")
        expectNil("32f")

        // Unit expressions — addition/subtraction converts the RHS and keeps the leftmost unit
        expectDisplay("10kg + 5kg", "15 kg")
        expectCopy("10kg + 5kg", "15 kg")
        expectExpression("10kg + 5kg", "10 kg + 5 kg")
        // Signs, parens and postfix % hug their operand instead of floating as separate words
        expectExpression("10kg * 3%", "10 kg × 3%")
        expectExpression("(10kg + 5kg) * 3%", "(10 kg + 5 kg) × 3%")
        expectExpression("-5kg + 2kg", "-5 kg + 2 kg")
        expectExpression("5 feet 3 inches", "5 ft 3 in")
        expectBadges("10kg + 5kg", source: "Expression", target: "Kilograms")
        expectDisplay("10kg + 10g", "10,010 g")  // issue #64, answered in the last unit typed
        expectDisplay("10kg + 500g", "10,500 g")
        expectDisplay("500g + 1kg", "1.5 kg")
        expectCopy("500g + 1kg", "1.5 kg")
        expectDisplay("10lb + 5kg", "9.5359237 kg")
        expectDisplay("1m + 50cm", "150 cm")
        expectDisplay("2hr + 30min", "150 min")
        expectDisplay("1GiB + 512MiB", "1,536 MiB")
        expectDisplay("1L - 250mL", "750 mL")
        expectDisplay("-5kg + 2kg", "-3 kg")
        expectDisplay("-(2kg + 500g)", "-2,500 g")
        expectDisplay("10 pounds + 5 pounds", "15 lb")  // unit wins the currency collision
        expectDisplay("1m² + 10ft²", "20.76391042 ft²")
        expectDisplay("1L + 1cup", "5.226752838 cup")
        expectDisplay("1GB + 1GiB", "1.931322575 GiB")
        expectDisplay("90deg + 1rad", "2.570796327 rad")
        expectDisplay("60mph + 10kmh", "106.56064 km/h")
        expectDisplay("1bar + 10psi", "24.50377377 psi")
        expectDisplay("1Gbps + 500Mbps", "1,500 Mbps")

        // Unit-expression precedence, parentheses, scalar operations, and cancellation
        expectDisplay("10kg + 2 * 5kg", "20 kg")
        expectDisplay("(10kg + 5kg) * 2", "30 kg")
        expectDisplay("2 * (3kg + 500g)", "7,000 g")
        expectDisplay("20kg / 2 + 3kg", "13 kg")
        expectDisplay("20kg / (2 + 3)", "4 kg")
        expectDisplay("5kg * 3", "15 kg")
        expectDisplay("10kg / 4", "2.5 kg")
        expectDisplay("5kg / 2kg", "2.5")
        expectBadges("5kg / 2kg", source: "Expression", target: "Result")
        expectDisplay("5kg / 500g", "10")
        expectDisplay("1kg / 3", "0.3333333333 kg")
        expectDisplay("10kg * (2 + 3)", "50 kg")
        expectDisplay("10kg / (2 * 5)", "1 kg")
        expectDisplay("(10kg * 3) / 5kg", "6")
        expectDisplay("10kg / (5kg / 2)", "4")
        expectDisplay("(2kg + 500g) * 4", "10,000 g")
        expectDisplay("(20kg - 5kg) / 3", "5 kg")

        // Percentages carry through quantity arithmetic
        expectDisplay("10kg + 20%", "12 kg")
        expectDisplay("10kg - 20%", "8 kg")
        expectDisplay("10kg * 20%", "2 kg")
        expectDisplay("10kg * 3%", "0.3 kg")
        expectDisplay("3% * 10kg", "0.3 kg")
        expectDisplay("10kg * 0%", "0 kg")
        expectDisplay("10kg * -3%", "-0.3 kg")
        expectDisplay("10kg / 25%", "40 kg")
        expectDisplay("10kg / 200%", "5 kg")
        expectDisplay("10kg * 3% + 1kg", "1.3 kg")
        expectDisplay("(10kg + 5kg) * 3%", "0.45 kg")
        expectDisplay("10kg * 3% to g", "300 g")
        expectCopy("10kg * 3% to g", "300 g")
        expectDisplay("20% of (10kg + 5kg)", "3 kg")
        expectDisplay("3% of 10kg", "0.3 kg")
        expectNil("10kg / 0%")
        expectDisplay("19m + 47%", "27.93 m")  // documented Raycast behavior

        // Incomplete expressions retain the last complete, actionable result
        expectDisplay("10 +", "10")
        expectDisplay("10 -", "10")
        expectDisplay("10 *", "10")
        expectDisplay("10 /", "10")
        expectDisplay("10 ^", "10")
        expectDisplay("10k +", "10,000")
        expectCopy("10k +", "10000")
        expectDisplay("10kg *", "10 kg")
        expectDisplay("10kg + 500g +", "10,500 g")
        expectDisplay("(10kg + 500g) *", "10,500 g")
        expectDisplay("10kg * 3% +", "0.3 kg")
        expectDisplay("20% of 450 +", "90")
        expectBadges("10 +", source: "Expression", target: "Result")
        expectBadges("10kg *", source: "Expression", target: "Kilograms")
        expectNil("+")
        expectNil("10 + nonsense")
        expectNil("10 + (")
        expectNil("10 of")  // a stray English word is a search, not a partial expression

        // A partial after a conversion echoes the typed text, and keeps the source radix / units
        expectExpression("10km to mi *", "10km to mi ×")
        expectDisplay("10km to mi *", "6.213711922 mi")
        expectExpression("255 to hex +", "255 to hex +")
        expectBadges("0xff -", source: "Hexadecimal", target: "Decimal")
        expectDisplay("0xff -", "255")

        // A conversion suffix applies to the complete unit expression
        expectDisplay("(1kg + 500g) to lb", "3.306933933 lb")
        expectDisplay("10kg + 500g to lb", "23.14853753 lb")
        expectDisplay("(10lb + 5kg) to kg", "9.5359237 kg")
        expectDisplay("(1m + 50cm) to ft", "4.921259843 ft")
        expectBadges("(1kg + 500g) to lb", source: "Expression", target: "Pounds")
        expectError("(1kg + 500g) to m", "Cannot convert Weight to Length.")

        // Adjacent compatible quantities are additive, matching common composite-unit notation.
        // Composite reads as one quantity in its leading unit; an explicit operator answers in the last.
        expectDisplay("5 feet 3 inches to cm", "160.02 cm")
        expectDisplay("5 feet 3 inches", "5.25 ft")
        expectDisplay("1hr 30min", "1.5 hr")
        expectDisplay("5feet + 1m", "2.524 m")
        expectBadges("5feet + 1m", source: "Expression", target: "Meters")
        expectDisplay("1kg + 500g + 2lb", "5.306933933 lb")  // chained: the last unit wins
        expectDisplay("2 * 5kg", "10 kg")
        expectDisplay("3 * 2m", "6 m")

        // Affine temperatures only combine in the same unit; mixed absolute scales are ambiguous
        expectDisplay("20 celsius + 10 celsius", "30 °C")
        expectDisplay("68 fahrenheit - 32 fahrenheit", "36 °F")
        expectError(
            "20 celsius + 50 fahrenheit",
            "Cannot combine temperatures with different units.")

        // Clear dimensional mistakes are errors; incomplete or non-finite input stays silent
        expectError("1kg + 1m", "Cannot add Weight and Length.")
        expectError("1kg + 1hr", "Cannot add Weight and Time.")
        // A bare number written against a quantity takes its unit
        expectDisplay("1kg + 1", "2 kg")
        expectDisplay("10kg + 5", "15 kg")
        expectDisplay("5kg+5", "10 kg")
        expectDisplay("5 + 10kg", "15 kg")
        expectDisplay("$10 + 5", "15.00 USD")
        expectBadges("5kg+5", source: "Expression", target: "Kilograms")
        expectDisplay("10kg + -20%", "9.8 kg")  // unary minus drops percent, as in `450 + -20%`
        // Adjacency is different: there a bare number is a unit still being typed, so it stays silent
        expectNil("1hr 30")  // mid-way through "1hr 30min"
        expectNil("5 feet 3")  // mid-way through "5 feet 3 inches"
        expectError(
            "1kg * 1m",
            "Multiplication of two unit values is not supported.")
        expectError("1 / 1kg", "Division by a unit value is not supported.")
        expectNil("(2m)^2")
        expectNil("sqrt(4kg)")
        expectNil("1kg!")
        expectDisplay("10kg +", "10 kg")
        expectCopy("10kg +", "10 kg")
        expectExpression("10kg +", "10 kg +")
        expectBadges("10kg +", source: "Expression", target: "Kilograms")
        expectNil("10kg + nonsense")
        expectNil("10unknown + 5unknown")
        expectNil("10kg / 0")
        expectDisplay("1234kg + 1kg", "1,235 kg")
        expectCopy("1234kg + 1kg", "1235 kg")

        // Date/time — evaluated against a fixed clock: Fri 2026-07-24 00:18 UTC
        expectDisplayAt("hrs till 9am", "8.7 hours")
        expectBadgesAt("hrs till 9am", source: "12:18 AM", target: "9:00 AM")
        expectDisplayAt("hrs till july", "8,207.7 hours")
        expectBadgesAt("hrs till july", source: "12:18 AM", target: "12:00 AM")
        expectDisplayAt("days till 9april", "259 days")
        expectBadgesAt(
            "days till 9april", source: "Friday, 24 July", target: "Friday, 9 April, 2027")
        expectDisplayAt("days till july", "342 days")
        expectBadgesAt(
            "days till july", source: "Friday, 24 July", target: "Thursday, 1 July, 2027")
        expectDisplayAt("days until tomorrow", "1 day")
        expectDisplayAt("weeks till 9april", "37 weeks")  // 259 / 7
        expectDisplayAt("today + 3 weeks", "Friday, 14 August")
        expectDisplayAt("now + 90 min", "Friday, 24 July at 1:48 AM")
        expectDisplayAt("jul 4 - today", "345 days")
        expectBadgesAt("jul 4 - today", source: "Sunday, 4 July, 2027", target: "Friday, 24 July")
        // Arithmetic with spaced operators must still be plain math, not date math
        expectDisplayAt("10 - 3", "7")
        expectDisplayAt("450 + 20%", "540")
        // Letter-free `m/d - m/d` is fraction math, not a date difference (both operands are valid arithmetic)
        expectDisplayAt("5/2 - 1/2", "2")
        expectDisplayAt("3/4 - 1/4", "0.5")
        expectDisplayAt("1/2 - 1/4", "0.25")
        // A slash date still reads as a date when the other side names a keyword
        expectDisplayAt("9/4 - today", "42 days")
        expectDisplayAt("today - 9/4", "-42 days")
        // Bare date/unit words alone are app searches, not cards
        expectNilAt("today")
        expectNilAt("july")
        expectNilAt("tomorrow")

        // Angle units (deg is a real unit now, not just a trig postfix)
        expectDisplay("1 deg", "0.01745329252 rad")
        expectExpression("1 deg", "1 deg")
        expectBadges("1 deg", source: "Degrees", target: "Radians")
        expectDisplay("90 deg to rad", "1.570796327 rad")
        expectDisplay("1 rad to deg", "57.29577951 deg")
        expectDisplay("1 turn to deg", "360 deg")
        expectDisplay("200 grad to deg", "180 deg")
        expectDisplay("sin(30deg)", "0.5")  // trig postfix still works inside parens

        // Implied quantity of 1 for number-less conversions
        expectDisplay("day to s", "86,400 s")
        expectDisplay("deg to rad", "0.01745329252 rad")
        expectDisplay("m to ft", "3.280839895 ft")

        // `unit unit` shorthand → 1 of the first in the second
        expectDisplay("day s", "86,400 s")
        expectBadges("day s", source: "Days", target: "Seconds")
        expectDisplay("days s", "86,400 s")
        expectDisplay("hr min", "60 min")
        expectNil("m s")  // different categories → no card, no error

        // Extra unit categories: speed / pressure / data rate
        expectDisplay("100 kmh to mph", "62.13711922 mph")
        expectDisplay("60 mph to kmh", "96.56064 km/h")
        expectDisplay("100 mbps to kbps", "100,000 Kbps")
        expectBadges("100 kmh to mph", source: "Kilometers per Hour", target: "Miles per Hour")

        // Percentage phrasings
        expectDisplay("20% off 500", "400")
        expectDisplay("50 as % of 200", "25%")

        // Badges on paths that previously had none
        expectBadges("255 to hex", source: "Decimal", target: "Hexadecimal")
        expectBadges("0xff to decimal", source: "Hexadecimal", target: "Decimal")
        expectBadges("3*3", source: "Expression", target: "Result")
        expectBadges("20% off 500", source: "Expression", target: "Result")

        // days since — past elapsed, against the fixed clock (Fri 2026-07-24)
        expectDisplayAt("days since 9jul", "15 days")
        expectBadgesAt("days since 9jul", source: "Thursday, 9 July", target: "Friday, 24 July")
        expectDisplayAt("weeks since 3jul", "3 weeks")
        expectDisplayAt("days since yesterday", "1 day")
        // Date ± duration now carries the resolved start as a source badge
        expectBadgesAt("today + 3 weeks", source: "Friday, 24 July", target: "Result")

        // Implicit-base phrasings, rewritten onto `moment ± duration` before dispatch
        expectDisplayAt("35 days ago", "Friday, 19 June")
        expectBadgesAt("35 days ago", source: "Friday, 24 July", target: "Result")
        expectDisplayAt("3 weeks from now", "Friday, 14 August")
        expectDisplayAt("35 minutes ago", "Thursday, 23 July at 11:43 PM")  // sub-day works off now
        expectDisplayAt("2 hours from now", "Friday, 24 July at 2:18 AM")
        expectDisplayAt("1 day ago", "Thursday, 23 July")
        expectDisplayAt("+ 2 years", "Monday, 24 July, 2028")
        expectDisplayAt("- 3 days", "Tuesday, 21 July")
        expectDisplayAt("+ 90 min", "Friday, 24 July at 1:48 AM")
        expectNilAt("chicago")  // ` ago` is matched as a suffix, never mid-word
        expectNilAt("long ago")
        expectNilAt("ago")
        expectNilAt("from now")
        expectNilAt("+ pizza")
        expectNilAt("- 3 pizzas")

        // Months and years, counted with calendar components rather than a seconds divisor
        expectDisplayAt("today + 3 months", "Saturday, 24 October")
        expectDisplayAt("today + 2 years", "Monday, 24 July, 2028")
        expectDisplayAt("today - 6 months", "Saturday, 24 January")
        expectDisplayAt("today + 1 month", "Monday, 24 August")
        expectDisplayAt("months till christmas", "5 months")
        expectDisplayAt("years till 2030-01-01", "3 years")
        expectNilAt("today + 3 fortnights")

        // Fixed-date holidays, matched before atomizing so multi-word names dodge the two-atom limit
        expectDisplayAt("days till christmas", "154 days")
        expectBadgesAt(
            "days till christmas", source: "Friday, 24 July", target: "Friday, 25 December")
        expectDisplayAt("days till xmas", "154 days")
        expectDisplayAt("days until new year", "161 days")
        expectDisplayAt("days till halloween", "99 days")
        expectDisplayAt("days till valentines day", "205 days")
        expectDisplayAt("weeks till christmas", "22 weeks")
        expectDisplayAt("days since christmas", "211 days")
        expectNilAt("christmas")  // a bare event name is still a search
        expectNilAt("days till atlantis")

        // Currency — against the fixed `fx` table below (1 USD = 0.92 EUR = 0.79 GBP = 157 JPY)
        expectDisplay("1 euro to dollars", "1.09 USD")
        expectExpression("1 euro to dollars", "1 EUR")
        expectBadges("1 euro to dollars", source: "Euro", target: "US Dollar")
        expectDisplay("50 GBP in euros", "58.23 EUR")
        expectDisplay("100 dollars to yen", "15,700.00 JPY")
        expectDisplay("100 usd -> eur", "92.00 EUR")
        expectDisplay("2*50 usd to eur", "92.00 EUR")  // expression on the value side
        expectDisplay("eur to usd", "1.09 USD")  // implied amount of 1
        expectCopy("100 dollars to yen", "15700.00 JPY")
        // Currency signs, prefixed and suffixed
        expectDisplay("€20 to GBP", "17.17 GBP")
        expectDisplay("20€ to GBP", "17.17 GBP")
        expectDisplay("USD1K to EUR", "920.00 EUR")
        expectDisplay("1kUSD to EUR", "920.00 EUR")
        expectDisplay("£50 in dollars", "63.29 USD")
        expectDisplay("$100 to yen", "15,700.00 JPY")
        // Sub-cent cross-rates widen instead of collapsing to 0.00
        expectDisplay("1 jpy to usd", "0.006369 USD")
        // …and stay in plain notation past 1e-5, where "%g" would flip to "5.539e-05"
        expectDisplay("1 idr to usd", "0.00005539 USD")
        expectCopy("1 idr to usd", "0.00005539 USD")
        // Currency never steals a query the unit table can answer
        expectDisplay("10 pounds to kilograms", "4.5359237 kg")
        expectDisplay("10 pounds", "4.5359237 kg")
        expectDisplay("10 pounds to euros", "11.65 EUR")
        expectBadges("10 pounds to euros", source: "British Pound", target: "Euro")
        // Currency ↔ unit is a friendly category error, like Weight ↔ Time
        expectError("10 usd to kg", "Cannot convert Currency to Weight.")
        expectError("10 kg to usd", "Cannot convert Weight to Currency.")
        // A known currency the snapshot doesn't quote, and no snapshot at all
        expectError("5 usd to npr", "No exchange rate for NPR.")
        expectErrorWithoutRates(
            "1 eur to usd", "Exchange rates unavailable — check your connection.")
        expectNil("10 usd to nonsense")
        expectNil("usd")  // a lone code is still an app search
        expectNil("btc")  // crypto isn't in the table — Frankfurter is central-bank fiat only
        // The table is generated from the feed's own currency list, so codes nobody hand-typed still
        // resolve — reaching "no rate" (not "no card") is what proves recognition.
        expectError("5 usd to zmw", "No exchange rate for ZMW.")
        expectError("5 usd to afn", "No exchange rate for AFN.")
        check(
            "CurrencyData sizes", expected: "true",
            got:
                "\(CurrencyData.all.count >= 120 && CurrencyData.signs.count >= 20 && CurrencyData.aliases.count >= 100)"
        )
        // Badges come from CLDR's label, which is shorter than the registry name where it matters
        expectBadges("1 chf to usd", source: "Swiss Franc", target: "US Dollar")
        expectBadges("1 aed to usd", source: "UAE Dirham", target: "US Dollar")
        // Nouns only one currency claims are generated — nobody hand-typed these
        expectError("1 zloty to usd", "No exchange rate for PLN.")
        expectError("1 forint to usd", "No exchange rate for HUF.")
        expectError("1 taka to usd", "No exchange rate for BDT.")
        expectError("1 rand to usd", "No exchange rate for ZAR.")
        expectDisplay("1 euro to dollars", "1.09 USD")
        // Accented nouns resolve with or without the accent
        expectError("1 krónur to usd", "No exchange rate for ISK.")
        expectError("1 kronur to usd", "No exchange rate for ISK.")
        // Nouns several currencies share are the hand-written part, and they must still win
        expectDisplay("100 dollars to yen", "15,700.00 JPY")
        expectDisplay("10 pounds to euros", "11.65 EUR")
        expectDisplay("1 franc to usd", "1.23 USD")
        expectError("1 peso to usd", "No exchange rate for MXN.")
        // `krona` is contested (SEK vs ISK) and deliberately assigned to neither
        expectNil("1 krona to usd")
        // Slang is no longer carried: CLDR has no "quid", and we don't hand-maintain synonyms
        expectNil("50 quid to usd")
        expectNil("100 bucks to eur")
        // The last word of a name isn't always its noun — "Special Drawing Rights" is not a "rights"
        expectNil("1 rights to usd")
        // A result too small to show at all reads as a clean zero, never "-0.00"
        expectDisplay("-0.0000000000001 usd to eur", "0.00 EUR")
        expectDisplay("0 usd to eur", "0.00 EUR")
        expectDisplay("-5 usd to eur", "-4.60 EUR")
        // CUP (Cuban peso) is a generated code that collides with a unit; volume still wins
        expectDisplay("1 cup to ml", "236.5882365 mL")
        expectDisplay("1 cup to tbsp", "16 tbsp")

        // Currency expressions — still pure and deterministic against the injected rate table
        expectDisplay("10$", "10.00 USD")
        expectExpression("10$", "10 USD")
        expectBadges("10$", source: "Expression", target: "US Dollar")
        expectDisplay("$10 + $5", "15.00 USD")
        expectDisplay("10$ + 5$", "15.00 USD")
        expectDisplay("$10 + €5", "14.20 EUR")
        expectDisplay("€5 + $10", "15.43 USD")
        // Sign-first money echoes amount-first, like every other quantity
        expectExpression("$10 + €5", "10 USD + 5 EUR")
        expectExpression("10$ + 5€", "10 USD + 5 EUR")
        expectDisplay("$10 * 2", "20.00 USD")
        expectDisplay("$10 / 4", "2.50 USD")
        expectDisplay("$10 / $2", "5")
        expectDisplay("$100 * 3%", "3.00 USD")
        expectDisplay("3% * $100", "3.00 USD")
        expectDisplay("$100 / 25%", "400.00 USD")
        expectDisplay("($100 * 3%) to eur", "2.76 EUR")
        expectDisplay("($10 + $5) to eur", "13.80 EUR")
        expectDisplay("$10 +", "10.00 USD")
        expectBadges("$10 +", source: "Expression", target: "US Dollar")
        expectError("$10 + 5kg", "Cannot add Currency and Weight.")
        expectErrorWithoutRates(
            "$10 + $5", "Exchange rates unavailable — check your connection.")
        expectErrorWithoutRates(
            "$100 * 3%", "Exchange rates unavailable — check your connection.")
        expectErrorWithoutRates(
            "10$", "Exchange rates unavailable — check your connection.")

        // Consent gate: without it the currency path doesn't exist. Not an error card explaining a
        // feature the user never enabled — no card at all, so the query falls through to app search.
        expectNilWithoutConsent("1 euro to dollars")
        expectNilWithoutConsent("100 dollars to yen")
        expectNilWithoutConsent("50 GBP in euros")
        expectNilWithoutConsent("eur to usd")
        expectNilWithoutConsent("€20 to GBP")
        expectNilWithoutConsent("2*50 usd to cad")
        expectNilWithoutConsent("1 zloty to eur")
        expectNilWithoutConsent("10$")
        expectNilWithoutConsent("$10 + $5")
        expectNilWithoutConsent("$10 + €5")
        expectNilWithoutConsent("$100 * 3%")
        expectNilWithoutConsent("$10 +")
        expectNilWithoutConsent("($10 + $5) to eur")
        expectNilWithoutConsent("$10 + 5kg")
        // Even the friendly category error stays silent — it would leak that currency exists.
        expectNilWithoutConsent("10 usd to kg")
        expectNilWithoutConsent("10 kg to usd")
        // Everything that isn't currency is untouched by the gate.
        expectDisplayWithoutConsent("10 pounds to kilograms", "4.5359237 kg")
        expectDisplayWithoutConsent("10 pounds", "4.5359237 kg")
        expectDisplayWithoutConsent("1 cup to ml", "236.5882365 mL")
        expectDisplayWithoutConsent("10km to mi", "6.213711922 mi")
        expectDisplayWithoutConsent("2+2", "4")
        expectDisplayWithoutConsent("255 to hex", "0xFF")
        expectDisplayWithoutConsent("20% off 500", "400")

        print("\n\(passes) passed, \(failures) failed")
        exit(failures == 0 ? 0 : 1)
    }

    // MARK: - Fixed clock for deterministic date/time tests (Fri 2026-07-24 00:18:00 UTC)

    static let clock: (now: Date, calendar: Calendar) = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US")
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 24
        components.hour = 0
        components.minute = 18
        components.second = 0
        return (calendar.date(from: components)!, calendar)
    }()

    // MARK: - Fixed exchange rates so currency answers are deterministic

    /// NPR, ZMW and AFN are deliberately absent: the table recognizes them (they're in the generated
    /// list), so a query for one must reach "no exchange rate" rather than falling through to no card.
    static let fx = CurrencyRates(
        base: "USD",
        rates: [
            "USD": 1, "EUR": 0.92, "GBP": 0.79, "JPY": 157, "INR": 83.5, "CAD": 1.36,
            "KRW": 1330, "IDR": 18053, "CHF": 0.81, "AED": 3.6725,
        ],
        fetchedAt: Date(timeIntervalSince1970: 1_785_000_000))

    // MARK: - Helpers

    static func expectDisplayAt(_ query: String, _ expected: String) {
        guard
            case .value(let display, _)? = CalcEngine.evaluate(
                query, now: clock.now, calendar: clock.calendar)?.payload
        else {
            fail(query, expected: expected, got: "nil / error")
            return
        }
        check(query, expected: expected, got: display)
    }

    static func expectBadgesAt(_ query: String, source: String, target: String) {
        guard let result = CalcEngine.evaluate(query, now: clock.now, calendar: clock.calendar)
        else {
            fail(query, expected: "\(source) → \(target)", got: "nil")
            return
        }
        check(query + " [source badge]", expected: source, got: result.sourceBadge ?? "nil")
        check(query + " [target badge]", expected: target, got: result.targetBadge ?? "nil")
    }

    static func expectNilAt(_ query: String) {
        if let result = CalcEngine.evaluate(query, now: clock.now, calendar: clock.calendar) {
            fail(query, expected: "nil", got: "\(result.payload)")
        } else {
            passes += 1
        }
    }

    static func expectBadges(_ query: String, source: String, target: String) {
        guard let result = CalcEngine.evaluate(query, currency: .on(fx)) else {
            fail(query, expected: "\(source) → \(target)", got: "nil")
            return
        }
        check(query + " [source badge]", expected: source, got: result.sourceBadge ?? "nil")
        check(query + " [target badge]", expected: target, got: result.targetBadge ?? "nil")
    }

    static func expectDisplay(_ query: String, _ expected: String) {
        guard case .value(let display, _)? = CalcEngine.evaluate(query, currency: .on(fx))?.payload
        else {
            fail(query, expected: expected, got: "nil / error")
            return
        }
        check(query, expected: expected, got: display)
    }

    static func expectCopy(_ query: String, _ expected: String) {
        guard case .value(_, let copy)? = CalcEngine.evaluate(query, currency: .on(fx))?.payload
        else {
            fail(query, expected: expected, got: "nil / error")
            return
        }
        check(query, expected: expected, got: copy)
    }

    static func expectError(_ query: String, _ expected: String) {
        guard case .error(let message)? = CalcEngine.evaluate(query, currency: .on(fx))?.payload
        else {
            fail(query, expected: "error: \(expected)", got: "nil / value")
            return
        }
        check(query, expected: expected, got: message)
    }

    /// Consented, but no snapshot has landed yet — first run, or still offline.
    static func expectErrorWithoutRates(_ query: String, _ expected: String) {
        guard case .error(let message)? = CalcEngine.evaluate(query, currency: .on(nil))?.payload
        else {
            fail(query, expected: "error: \(expected)", got: "nil / value")
            return
        }
        check(query, expected: expected, got: message)
    }

    /// No consent: the currency path must not engage. Checks the explicit `.off` source and the
    /// default argument, since a caller that forgets to pass one must still get the feature off.
    static func expectNilWithoutConsent(_ query: String) {
        if let result = CalcEngine.evaluate(query, currency: .off) {
            fail(query, expected: "nil (consent withheld)", got: "\(result.payload)")
        } else if let result = CalcEngine.evaluate(query) {
            fail(query, expected: "nil (default source)", got: "\(result.payload)")
        } else {
            passes += 1
        }
    }

    /// A non-currency answer that must survive with the feature switched off.
    static func expectDisplayWithoutConsent(_ query: String, _ expected: String) {
        guard case .value(let display, _)? = CalcEngine.evaluate(query, currency: .off)?.payload
        else {
            fail(query, expected: expected, got: "nil / error")
            return
        }
        check(query, expected: expected, got: display)
    }

    static func expectExpression(_ query: String, _ expected: String) {
        guard let result = CalcEngine.evaluate(query, currency: .on(fx)) else {
            fail(query, expected: expected, got: "nil")
            return
        }
        check(query, expected: expected, got: result.expression)
    }

    static func expectNil(_ query: String) {
        if let result = CalcEngine.evaluate(query, currency: .on(fx)) {
            fail(query, expected: "nil", got: "\(result.payload)")
        } else {
            passes += 1
        }
    }

    static func check(_ query: String, expected: String, got: String) {
        if got == expected {
            passes += 1
        } else {
            fail(query, expected: expected, got: got)
        }
    }

    static func fail(_ query: String, expected: String, got: String) {
        failures += 1
        print("FAIL  \(query)\n      expected: \(expected)\n      got:      \(got)")
    }
}
