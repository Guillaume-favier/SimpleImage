import Foundation
import SimpleImage
import UIKit

private enum AssociatedKeys {
  nonisolated(unsafe) static var currentTask = true
  nonisolated(unsafe) static var requestID = true
}

@MainActor
extension UIImageView {
  public fileprivate(set) var si_currentTask: SimpleImageTask? {
    get { objc_getAssociatedObject(self, &AssociatedKeys.currentTask) as? SimpleImageTask }
    set { objc_setAssociatedObject(self, &AssociatedKeys.currentTask, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
  }

  fileprivate var si_requestID: UUID? {
    get { objc_getAssociatedObject(self, &AssociatedKeys.requestID) as? UUID }
    set { objc_setAssociatedObject(self, &AssociatedKeys.requestID, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
  }

  public func si_cancelImageDownload() {
    si_requestID = nil
    si_currentTask?.cancel()
    si_currentTask = nil
  }

  public func si_setImage(
    using imageManager: SimpleImageManager,
    request: URLRequest,
    processors: [any SimpleImageProcessor] = [],
    placeholderImage: UIImage? = nil
  ) {
    si_cancelImageDownload()
    image = placeholderImage
    let requestID = UUID()
    si_requestID = requestID
    si_currentTask = imageManager.retrieveImage(request: request, processors: processors) { [weak self] result in
      guard let self, self.si_requestID == requestID else { return }
      self.si_currentTask = nil
      if case .success(let image) = result { self.image = image }
    }
  }
}

@MainActor
public extension SimpleImageAnimatedView {
  func si_setAnimatedImage(
    using imageManager: SimpleImageManager,
    request: URLRequest,
    processors: [any SimpleImageProcessor] = [],
    placeholderImage: UIImage? = nil
  ) {
    si_cancelImageDownload()
    si_animatedImage = nil
    image = placeholderImage

    let requestID = UUID()
    si_requestID = requestID
    si_currentTask = imageManager.retrieveImage(request: request, processors: processors) { [weak self] result in
      guard let self, self.si_requestID == requestID else { return }
      self.si_currentTask = nil
      guard case .success(let image) = result else { return }

      if let animatedImage = image.si_animatedImage, animatedImage.isAnimated {
        self.si_animatedImage = animatedImage
      } else {
        self.image = image
      }
    }
  }
}
