import SwiftUI
import UIKit

enum AppearanceSettingsKey {
    static let theme = "appearance.theme"
    static let colorScheme = "appearance.colorScheme"
    static let backgroundEnabled = "appearance.backgroundEnabled"
    static let backgroundOpacity = "appearance.backgroundOpacity"
    static let backgroundBlur = "appearance.backgroundBlur"
    static let backgroundRevision = "appearance.backgroundRevision"
}

enum AppTheme: String, CaseIterable, Identifiable {
    case ocean
    case violet
    case rose
    case mint
    case teal
    case orange
    case indigo
    case graphite

    var id: String { rawValue }

    var name: String {
        switch self {
        case .ocean: return "海洋蓝"
        case .violet: return "星云紫"
        case .rose: return "樱花粉"
        case .mint: return "薄荷绿"
        case .teal: return "青绿色"
        case .orange: return "暖阳橙"
        case .indigo: return "夜空靛"
        case .graphite: return "石墨灰"
        }
    }

    var accentColor: Color {
        switch self {
        case .ocean: return Color(red: 0.16, green: 0.48, blue: 0.96)
        case .violet: return Color(red: 0.55, green: 0.34, blue: 0.93)
        case .rose: return Color(red: 0.94, green: 0.32, blue: 0.58)
        case .mint: return Color(red: 0.18, green: 0.72, blue: 0.52)
        case .teal: return Color(red: 0.08, green: 0.66, blue: 0.72)
        case .orange: return Color(red: 0.96, green: 0.48, blue: 0.17)
        case .indigo: return Color(red: 0.32, green: 0.36, blue: 0.86)
        case .graphite: return Color(red: 0.38, green: 0.42, blue: 0.49)
        }
    }

    var secondaryColor: Color {
        switch self {
        case .ocean: return Color(red: 0.22, green: 0.76, blue: 0.98)
        case .violet: return Color(red: 0.78, green: 0.42, blue: 0.96)
        case .rose: return Color(red: 1.00, green: 0.58, blue: 0.67)
        case .mint: return Color(red: 0.42, green: 0.86, blue: 0.67)
        case .teal: return Color(red: 0.25, green: 0.84, blue: 0.79)
        case .orange: return Color(red: 1.00, green: 0.70, blue: 0.24)
        case .indigo: return Color(red: 0.51, green: 0.48, blue: 0.96)
        case .graphite: return Color(red: 0.62, green: 0.66, blue: 0.72)
        }
    }
}

enum AppColorScheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var name: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum ChatBackgroundImageManager {
    private static var imageURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("chat_background.jpg")
    }

    static func save(_ image: UIImage) -> Bool {
        let maxDimension: CGFloat = 2400
        let maxSide = max(image.size.width, image.size.height)
        let scale = min(1, maxDimension / maxSide)
        let targetSize = CGSize(
            width: max(1, image.size.width * scale),
            height: max(1, image.size.height * scale)
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard let data = resized.jpegData(compressionQuality: 0.84) else { return false }
        do {
            try data.write(to: imageURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    static func load() -> UIImage? {
        UIImage(contentsOfFile: imageURL.path)
    }

    static func remove() {
        try? FileManager.default.removeItem(at: imageURL)
    }
}
