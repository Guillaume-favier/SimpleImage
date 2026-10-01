//
//  SimpleImageTask.swift
//  SimpleImage
//
//  Created by Faizan Durrani on 29/08/2026.
//

import Foundation
import UIKit

public final class SimpleImageTask: Sendable {
  enum State {
    case initialising
    case cacheTask(SimpleImageCacheTask)
    case downloadTask(SimpleImageDownloadTask)
    case processingTask(SimpleImageProcessingTask)
    case cancelled
    case finished
  }

  public let id: UUID
  public let imageRequest: SimpleImageRequest

  public var isCancelled: Bool {
    self.lock.withLock {
      if case .cancelled = self.state { return true }
      return false
    }
  }

  private let imageManager: SimpleImageManager?
  private nonisolated(unsafe) var state: State

  private let completionHandler: @Sendable (SimpleImageTask, Result<UIImage, Error>) -> Void
  private let lock = NSLock()
  private let progressHandler: SimpleImageManager.ProgressHandler?

  init(
    imageRequest: SimpleImageRequest,
    imageManager: SimpleImageManager,
    progressHandler: SimpleImageManager.ProgressHandler?,
    completionHandler: @escaping @Sendable (SimpleImageTask, Result<UIImage, Error>) -> Void
  ) {
    self.progressHandler = progressHandler
    self.id = UUID()
    self.imageRequest = imageRequest
    self.imageManager = imageManager
    self.state = .initialising
    self.completionHandler = completionHandler

    self.beginImageLoading()
  }

  public func cancel() {
    let previousState = lock.withLock { () -> State? in
      switch state {
      case .cancelled, .finished: return nil
      default:
        let previous = state
        state = .cancelled
        return previous
      }
    }
    guard let previousState else { return }
    switch previousState {
    case .cacheTask(let task): task.detach(task: self)
    case .downloadTask(let task): task.detach(task: self)
    case .processingTask(let task): task.detach(task: self)
    default: break
    }
    completionHandler(self, .failure(CancellationError()))
  }

  func reportProgress(_ fraction: Double) {
    let active = lock.withLock {
      switch state {
      case .cancelled, .finished: return false
      default: return true
      }
    }
    if active, fraction.isFinite { progressHandler?(min(1, max(0, fraction))) }
  }

  private func beginImageLoading() {
    if self.imageRequest.processors.isEmpty {
      self.loadImageFromNetwork()
    } else {
      self.loadImageFromCache()
    }
  }

  private func loadImageFromCache() {
    guard let imageManager else { return }

    let internalTask = imageManager.cacheTask(request: self.imageRequest)
    let installed: Bool

    self.lock.lock()
    switch self.state {
    case .cacheTask(let currentTask) where currentTask !== internalTask:
      self.state = .cacheTask(internalTask)
      installed = true

    case .initialising:
      self.state = .cacheTask(internalTask)
      installed = true

    default:
      installed = false
    }
    self.lock.unlock()

    guard installed else {
      internalTask.detach(task: self)
      return
    }

    switch internalTask.attach(task: self) {
    case .attached:
      let isStillCurrent = self.lock.withLock {
        if case .cacheTask(let currentTask) = self.state, currentTask === internalTask {
          return true
        }

        return false
      }

      if !isStillCurrent {
        internalTask.detach(task: self)
      }

    case .finished(let result):
      self.processImageResult(result)
    case .cancelled:
      self.loadImageFromCache()
    }
  }

  private func loadImageFromNetwork() {
    guard let imageManager else { return }

    let internalTask = imageManager.downloadTask(request: self.imageRequest)
    let installed: Bool

    self.lock.lock()
    switch self.state {
    case .downloadTask(let currentTask) where currentTask !== internalTask:
      self.state = .downloadTask(internalTask)
      installed = true

    case .initialising, .cacheTask:
      self.state = .downloadTask(internalTask)
      installed = true

    default:
      installed = false
    }
    self.lock.unlock()

    guard installed else {
      internalTask.detach(task: self)
      return
    }

    switch internalTask.attach(task: self) {
    case .attached:
      let isStillCurrent = self.lock.withLock {
        if case .downloadTask(let currentTask) = self.state, currentTask === internalTask {
          return true
        }

        return false
      }

      if !isStillCurrent {
        internalTask.detach(task: self)
      }

    case .finished(let result):
      self.processImageResult(result)
    case .cancelled:
      self.loadImageFromNetwork()
    }
  }

  private func processImage(_ container: ImageContainer) {
    guard let imageManager else { return }

    let internalTask = imageManager.processingTask(request: self.imageRequest, container: container)
    let installed: Bool

    self.lock.lock()
    switch self.state {
    case .processingTask(let currentTask) where currentTask !== internalTask:
      self.state = .processingTask(internalTask)
      installed = true

    case .downloadTask:
      self.state = .processingTask(internalTask)
      installed = true

    default:
      installed = false
    }
    self.lock.unlock()

    guard installed else {
      internalTask.detach(task: self)
      return
    }

    switch internalTask.attach(task: self) {
    case .attached:
      let isStillCurrent = self.lock.withLock {
        if case .processingTask(let currentTask) = self.state, currentTask === internalTask {
          return true
        }

        return false
      }

      if !isStillCurrent {
        internalTask.detach(task: self)
      }

    case .finished(let result):
      self.processImageResult(result)
    case .cancelled:
      self.processImage(container)
    }
  }

  func processImageResult(_ result: Result<ImageContainer, Error>) {
    let state = self.lock.withLock { self.state }

    switch (state, result) {
    case (.cacheTask, .failure):
      self.loadImageFromNetwork()

    case (.downloadTask, .success(let container)) where !self.imageRequest.processors.isEmpty:
      self.processImage(container)

    case (.cacheTask, let result),
      (.downloadTask, let result),
      (.processingTask, let result):
      self.finishLoading(with: result)

    case (.initialising, _), (.cancelled, _), (.finished, _):
      break
    }
  }

  private func finishLoading(with result: Result<ImageContainer, Error>) {
    self.lock.lock()
    switch self.state {
    case .cacheTask, .downloadTask, .processingTask:
      self.state = .finished
      self.lock.unlock()

      // Decode at the last moment — the cache stores bytes.
      switch result {
      case .success(let container):
        Task {
          do {
            let image = try await container.uiImage()
            self.completionHandler(self, .success(image))
          } catch {
            self.completionHandler(self, .failure(error))
          }
        }
      case .failure(let error):
        self.completionHandler(self, .failure(error))
      }
    default:
      self.lock.unlock()
    }
  }
}
