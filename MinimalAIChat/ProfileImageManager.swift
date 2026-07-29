import UIKit

struct ProfileImageManager {
    static var profileImageURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("profile_image.jpg")
    }
    
    static func save(_ image: UIImage) {
        DispatchQueue.global(qos: .userInitiated).async {
            let maxDimension: CGFloat = 300.0
            var targetSize = image.size
            let maxSide = max(image.size.width, image.size.height)
            
            if maxSide > maxDimension {
                let scale = maxDimension / maxSide
                targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            }
            
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0 // Ensure physical pixels match our computed targetSize
            let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
            
            let resizedImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
            
            if let data = resizedImage.jpegData(compressionQuality: 0.8) {
                try? data.write(to: profileImageURL, options: .atomic)
            }
        }
    }
    
    static func load() -> UIImage? {
        if FileManager.default.fileExists(atPath: profileImageURL.path) {
            return UIImage(contentsOfFile: profileImageURL.path)
        }
        return nil
    }
    
    static func remove() {
        if FileManager.default.fileExists(atPath: profileImageURL.path) {
            try? FileManager.default.removeItem(at: profileImageURL)
        }
    }
}

struct AssistantProfileImageManager {
    static var imageURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("assistant_profile_image.jpg")
    }

    static func save(_ image: UIImage) {
        let maxDimension: CGFloat = 500
        let maxSide = max(image.size.width, image.size.height)
        guard maxSide > 0 else { return }
        let scale = min(1, maxDimension / maxSide)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        if let data = rendered.jpegData(compressionQuality: 0.82) {
            try? data.write(to: imageURL, options: .atomic)
        }
    }

    static func load() -> UIImage? {
        UIImage(contentsOfFile: imageURL.path)
    }

    static func remove() {
        try? FileManager.default.removeItem(at: imageURL)
    }
}
