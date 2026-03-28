import CoreText
import Foundation

enum FontRegistration {
    static var isRegistered = false

    static func registerCustomFonts() {
        guard !isRegistered else { return }
        isRegistered = true

        if let fontURL = Bundle.module.url(forResource: "digital-7-mono", withExtension: "ttf", subdirectory: "Fonts") {
            var errorRef: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &errorRef)
        }
    }

    static let digital7Mono = "Digital-7 Mono"
}
