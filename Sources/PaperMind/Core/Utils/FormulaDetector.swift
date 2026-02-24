import Foundation

enum FormulaDetector {
    static func isLikelyFormula(_ text: String) -> Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return false }

        let formulaTokens = [
            "=", "\\", "^", "_", "∑", "∏", "∫", "∞", "≈", "≤", "≥", "→", "λ", "μ", "σ", "θ", "β", "α"
        ]

        let tokenHits = formulaTokens.reduce(into: 0) { partial, token in
            if value.contains(token) { partial += 1 }
        }

        let digitCount = value.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0) }.count
        let letterCount = value.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        let symbolSet = CharacterSet(charactersIn: "=+-*/^_()[]{}<>,.|:\\")
        let symbolCount = value.unicodeScalars.filter { symbolSet.contains($0) }.count

        let density = Double(symbolCount + digitCount) / Double(max(value.count, 1))

        if tokenHits >= 1 && density > 0.18 { return true }
        if tokenHits >= 2 { return true }
        if symbolCount >= 3 && digitCount >= 1 && letterCount >= 1 { return true }

        return false
    }
}
