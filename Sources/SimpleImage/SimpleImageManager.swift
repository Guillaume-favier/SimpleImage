//
//  SimpleImageManager.swift
//  SimpleImage
//
//  Created by Faizan Durrani on 29/08/2026.
//

import Foundation
import UIKit

enum SimpleImageError: Error {
  case invalidImageData
  case cacheMiss(cacheKey: String)
}

public final class SimpleImageManager: Sendable, Hashable {
  public static func == (lhs: SimpleImageManager, rhs: SimpleImageManager) -> Bool { lhs === rhs }
  public func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }

  public let imageLoader: SimpleImageLoader
  public let imageCache: SimpleImageCache
  public let imageTransformers: [SimpleImageTransformer]

  private nonisolated(unsafe) var cacheTasks: [String: SimpleImageCacheTask] = [:]
  private nonisolated(unsafe) var downloadTasks: [String: SimpleImageDownloadTask] = [:]
  private nonisolated(unsafe) var processingTasks: [String: SimpleImageProcessingTask] = [:]

  private let lock = NSLock()

  public init(
    imageLoader: SimpleImageLoader,
    imageCache: SimpleImageCache,
    imageTransformers: [SimpleImageTransformer]
  ) {
    self.imageLoader = imageLoader
    self.imageCache = imageCache
    self.imageTransformers = imageTransformers
  }

  public typealias CompletionHandler = @Sendable @MainActor (Result<UIImage, Error>) -> Void
  public typealias ProgressHandler = @Sendable (Double) -> Void

  @discardableResult
  public func retrieveImage(
    request: URLRequest,
    processors: [any SimpleImageProcessor] = [],
    progressHandler: ProgressHandler? = nil,
    completion: @escaping CompletionHandler
  ) -> SimpleImageTask {
    retrieveImage(
      imageRequest: SimpleImageRequest(urlRequest: request, processors: processors),
      progressHandler: progressHandler,
      completion: completion
    )
  }

  @discardableResult
  public func retrieveImage(
    imageRequest: SimpleImageRequest,
    progressHandler: ProgressHandler? = nil,
    completion: @escaping CompletionHandler
  ) -> SimpleImageTask {
    SimpleImageTask(
      imageRequest: imageRequest,
      imageManager: self,
      progressHandler: progressHandler,
      completionHandler: { _, result, _ in
        Task { @MainActor in completion(result) }
      }
    )
  }

  public func image(
    request: URLRequest,
    processors: [any SimpleImageProcessor] = [],
    progressHandler: ProgressHandler? = nil
  ) async throws -> UIImage {
    let cancellation = ImageTaskCancellation()
    return try await withTaskCancellationHandler {
      try Task.checkCancellation()
      return try await withCheckedThrowingContinuation { continuation in
        let task = retrieveImage(
          request: request,
          processors: processors,
          progressHandler: progressHandler,
          completion: { continuation.resume(with: $0) }
        )
        cancellation.install(task)
      }
    } onCancel: {
      cancellation.cancel()
    }
  }

  func cacheTask(request: SimpleImageRequest) -> SimpleImageCacheTask {
    self.lock.withLock {
      let taskIdentifier = request.cacheKey

      if let task = self.cacheTasks[taskIdentifier], !task.isCancelled {
        return task
      }

      let task = SimpleImageCacheTask(
        imageRequest: request,
        imageCache: self.imageCache,
        completionHandler: { task, imageResult, cacheKey in
          self.lock.withLock {
            if self.cacheTasks[taskIdentifier] === task {
              self.cacheTasks.removeValue(forKey: taskIdentifier)
            }
          }
        }
      )

      self.cacheTasks[taskIdentifier] = task
      return task
    }
  }

  func downloadTask(request: SimpleImageRequest) -> SimpleImageDownloadTask {
    self.lock.withLock {
      let taskIdentifier = request.unprocessedCacheKey

      if let task = self.downloadTasks[taskIdentifier], !task.isCancelled {
        return task
      }

      let task = SimpleImageDownloadTask(
        imageRequest: request,
        imageLoader: self.imageLoader,
        imageTransformers: self.imageTransformers,
        imageCache: self.imageCache,
        completionHandler: { [weak self] task, _, _ in
          guard let self else { return }
          self.lock.withLock {
            if self.downloadTasks[taskIdentifier] === task {
              self.downloadTasks.removeValue(forKey: taskIdentifier)
            }
          }
        }
      )

      self.downloadTasks[taskIdentifier] = task
      return task
    }
  }

  func processingTask(request: SimpleImageRequest, image: UIImage) -> SimpleImageProcessingTask {
    self.lock.withLock {
      let taskIdentifier = request.cacheKey

      if let task = self.processingTasks[taskIdentifier], !task.isCancelled {
        return task
      }

      let task = SimpleImageProcessingTask(
        imageRequest: request,
        image: image,
        imageCache: self.imageCache,
        completionHandler: { [weak self] task, _, _ in
          guard let self else { return }
          self.lock.withLock {
            if self.processingTasks[taskIdentifier] === task {
              self.processingTasks.removeValue(forKey: taskIdentifier)
            }
          }
        }
      )

      self.processingTasks[taskIdentifier] = task
      return task
    }
  }
}

private final class ImageTaskCancellation: @unchecked Sendable {
  private let lock = NSLock()
  private var task: SimpleImageTask?
  private var cancelled = false

  func install(_ task: SimpleImageTask) {
    let shouldCancel = lock.withLock {
      if cancelled { return true }
      self.task = task
      return false
    }
    if shouldCancel { task.cancel() }
  }

  func cancel() {
    let task = lock.withLock {
      cancelled = true
      let task = self.task
      self.task = nil
      return task
    }
    task?.cancel()
  }
}
