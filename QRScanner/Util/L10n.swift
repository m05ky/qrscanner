import Foundation

/// Localized strings; keys are the same as the Android string names.
enum L {
    static func t(_ key: String) -> String {
        return Bundle.main.localizedString(forKey: key, value: key, table: nil)
    }

    static func f(_ key: String, _ args: CVarArg...) -> String {
        return String(format: t(key), arguments: args)
    }
}
