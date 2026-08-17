//
//  ImageCompressor.swift
//  Yonder
//

import UIKit

/// Utility to downscale and compress images for local storage.
enum ImageCompressor {

    /// Resizes an image so that its maximum dimension does not exceed `maxDimension`,
    /// and returns JPEG image data with the specified compression quality.
    static func compress(image: UIImage, maxDimension: CGFloat = 500, compressionQuality: CGFloat = 0.8) -> Data? {
        let size = image.size
        guard size.width > 0 && size.height > 0 else { return nil }

        var newSize = size
        if size.width > maxDimension || size.height > maxDimension {
            if size.width > size.height {
                newSize = CGSize(width: maxDimension, height: size.height * (maxDimension / size.width))
            } else {
                newSize = CGSize(width: size.width * (maxDimension / size.height), height: maxDimension)
            }
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        return resizedImage.jpegData(compressionQuality: compressionQuality)
    }
}
