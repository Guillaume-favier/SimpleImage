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
  
  private let completionHandler: @Sendable (SimpleImageTask, Result<UIImage, Error>, String?) -> Void
  private let lock = NSLock()
  
  init(
    imageRequest: SimpleImageRequest,
    imageManager: SimpleImageManager,
    completionHandler: @escaping @Sendable (SimpleImageTask, Result<UIImage, Error>, String?) -> Void
  ) {
    self.id = UUID()
    self.imageRequest = imageRequest
    self.imageManager = imageManager
    self.state = .initialising
    self.completionHandler = completionHandler
    
    self.beginImageLoading()
  }
  
  public func cancel() {
    self.lock.lock()
    switch self.state {
      case .initialising:
        self.state = .cancelled
        self.lock.unlock()
        
      case .cacheTask(let simpleImageCacheTask):
        self.state = .cancelled
        self.lock.unlock()
        
        simpleImageCacheTask.detach(task: self)
        
      case .downloadTask(let simpleImageDownloadTask):
        self.state = .cancelled
        self.lock.unlock()
        
        simpleImageDownloadTask.detach(task: self)
        
      case .processingTask(let simpleImageProcessingTask):
        self.state = .cancelled
        self.lock.unlock()
        
        simpleImageProcessingTask.detach(task: self)
        
      case .cancelled, .finished:
        self.lock.unlock()
    }
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
  
  private func processImage(_ image: UIImage) {
    guard let imageManager else { return }
    
    let internalTask = imageManager.processingTask(request: self.imageRequest, image: image)
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
        self.processImage(image)
    }
  }
  
  func processImageResult(_ result: Result<UIImage, Error>) {
    let state = self.lock.withLock { self.state }
    
    switch (state, result) {
      case (.cacheTask(let simpleImageCacheTask), .failure(let image)):
        self.loadImageFromNetwork()
        
      case (.downloadTask, .success(let image)) where !self.imageRequest.processors.isEmpty:
        self.processImage(image)
        
      case (.processingTask, .success):
        self.finishLoading(with: result, cacheKey: self.imageRequest.cacheKey)
        
      case (.cacheTask, let result),
        (.downloadTask, let result),
        (.processingTask, let result):
        self.finishLoading(with: result, cacheKey: nil)
        
      case (.initialising, _), (.cancelled, _), (.finished, _):
        break
    }
  }
  
  private func finishLoading(with result: Result<UIImage, Error>, cacheKey: String?) {
    self.lock.lock()
    switch self.state {
      case .cacheTask, .downloadTask, .processingTask:
        self.state = .finished
        self.lock.unlock()
        
        self.completionHandler(self, result, cacheKey)
      default:
        self.lock.unlock()
    }
  }
}
