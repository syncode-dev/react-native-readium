import Combine
import Foundation
import R2Shared
import R2Streamer
import UIKit

@objc(CoverImageModule)
class CoverImageModule: NSObject {
  @objc static func requiresMainQueueSetup() -> Bool { return true }

  private lazy var streamer: Streamer = Streamer()
  private lazy var library: URL =
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

  private func importPublication(url: URL) async throws -> Publication {
    let publicationAsset = FileAsset(url: url)

    return try await withCheckedThrowingContinuation({ continuation in
      self.streamer.open(asset: publicationAsset, allowUserInteraction: false) { result in
        switch result {
        case .success(let pub):
            continuation.resume(returning: pub)
        case .failure(let error):
            continuation.resume(throwing: CoverImageError.openFailed(error))
        case .cancelled:
            continuation.resume(throwing: CoverImageError.cancelled)
        }
      }
    })
  }

  private func getCoverUrl() -> URL {
    let url = library.appendingPathComponent("Covers")
    try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url.appendingUniquePathComponent().appendingPathExtension("png")
  }

  private func storeCoverImage(filePath: String, guideWidth: NSNumber, guideHeight: NSNumber) async throws -> String? {
    let fileUrl = URL(fileURLWithPath: filePath)
    let publication = try await importPublication(url: fileUrl)

    guard let coverImage = publication.cover?.resized(guideWidth: guideWidth.cgFloatValue, guideHeight: guideHeight.cgFloatValue) else {
      throw CoverImageError.coverImageFailed
    }
    guard let cover = coverImage.pngData() else {
      throw CoverImageError.pngDataFailed
    }

    do {
      let coverUrl: URL = getCoverUrl()
      try cover.write(to: coverUrl)
      return coverUrl.absoluteString
    } catch {
      throw CoverImageError.writeFailed
    }
  }

  @objc
  public func getCoverImage(
    _ filePath: String,
    guideWidth: NSNumber,
    guideHeight: NSNumber,
    resolve: @escaping RCTPromiseResolveBlock,
    rejector reject: @escaping RCTPromiseRejectBlock
  ) -> Void {
    Task {
      do {
        let coverImageUrl = try await storeCoverImage(filePath: filePath, guideWidth: guideWidth, guideHeight: guideHeight)
        resolve(coverImageUrl)
      } catch (let error as CoverImageError) {
        reject("Can not get cover image.", error.errorDescription, nil)
      }
    }
  }

  public enum CoverImageError: LocalizedError {
    case openFailed(Error)
    case cancelled
    case unknown(String)
    case coverImageFailed
    case writeFailed
    case pngDataFailed

    var errorDescription: String? {
      switch self {
        case .openFailed(let error):
          return error.localizedDescription
        case .cancelled:
          return "Cancelled."
        case .unknown(let description):
          return description
        case .coverImageFailed:
          return "Can not get cover image."
        case .writeFailed:
          return "Can not write cover image."
        case .pngDataFailed:
          return "Can not get png data from cover image."
        default:
          return nil
      }
    }
  }
}

extension UIImage {
  func resized(guideWidth: CGFloat, guideHeight: CGFloat) -> UIImage? {
    if (guideWidth <= 0 && guideHeight <= 0) || (guideWidth > size.width && guideHeight > size.height) {
      return self
    }

    var width = guideWidth <= 0 ? size.width : guideWidth
    var height = guideHeight <= 0 ? size.height : guideHeight
    let imageRatio = size.width / size.height
    if (width / height > imageRatio) {
      width = height * imageRatio
    } else {
      height = width / imageRatio
    }

    let canvas = CGSize(width: width, height: height)
    let format = imageRendererFormat
    return UIGraphicsImageRenderer(size: canvas, format: format).image {
      _ in draw(in: CGRect(origin: .zero, size: canvas))
    }
  }
}

extension NSNumber {
  var cgFloatValue : CGFloat {
    var value : CGFloat = 0
    CFNumberGetValue(self, .cgFloatType, &value)
    return value
  }
}