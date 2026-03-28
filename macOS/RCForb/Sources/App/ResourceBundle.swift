import Foundation

enum ResourceBundle {
    static let bundle: Bundle = {
        let bundleName = "RCForb_RCForb"
        let execURL = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0])
        let execDir = execURL.deletingLastPathComponent()

        // Search: next to executable, in ../Resources, via Bundle.main
        let paths: [String] = [
            execDir.appendingPathComponent("\(bundleName).bundle").path,
            execDir.deletingLastPathComponent().appendingPathComponent("Resources").appendingPathComponent("\(bundleName).bundle").path,
            Bundle.main.bundleURL.appendingPathComponent("\(bundleName).bundle").path,
        ]

        for path in paths {
            if let b = Bundle(path: path) { return b }
        }

        if let resURL = Bundle.main.resourceURL {
            let resPath = resURL.appendingPathComponent("\(bundleName).bundle").path
            if let b = Bundle(path: resPath) { return b }
        }

        return Bundle.main
    }()
}
