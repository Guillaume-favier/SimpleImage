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

public final class SimpleImageManager: Sendable {
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
  
  public func retrieveImage(
    request: URLRequest,
    processors: [any SimpleImageProcessor]
  ) -> SimpleImageTask {
    let imageRequest = SimpleImageRequest(urlRequest: request, processors: processors)
    return SimpleImageTask(
      imageRequest: imageRequest,
      imageManager: self,
      completionHandler: { request, imageResult, cacheKey in
        // No-op
      }
    )
  }
  
  public func retrieveImage(
    imageRequest: SimpleImageRequest
  ) -> SimpleImageTask {
    return SimpleImageTask(
      imageRequest: imageRequest,
      imageManager: self,
      completionHandler: { request, imageResult, cacheKey in
        // No-op
      }
    )
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
        completionHandler: { task, imageResult, cacheKey in
          if let cacheKey, case .success(let image) = imageResult {
            Task {
              do {
                try await self.imageCache.cacheImage(image, forKey: cacheKey)
              } catch {
                // TODO: Implement erorr handling
              }
              
              self.lock.withLock {
                if self.downloadTasks[taskIdentifier] === task {
                  self.downloadTasks.removeValue(forKey: taskIdentifier)
                }
              }
            }
          } else {
            self.lock.withLock {
              if self.downloadTasks[taskIdentifier] === task {
                self.downloadTasks.removeValue(forKey: taskIdentifier)
              }
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
        completionHandler: { task, imageResult, cacheKey in
          if let cacheKey, case .success(let image) = imageResult {
            Task {
              do {
                try await self.imageCache.cacheImage(image, forKey: cacheKey)
              } catch {
                // TODO: Implement erorr handling
              }
              
              self.lock.withLock {
                if self.processingTasks[taskIdentifier] === task {
                  self.processingTasks.removeValue(forKey: taskIdentifier)
                }
              }
            }
          } else {
            self.lock.withLock {
              if self.processingTasks[taskIdentifier] === task {
                self.processingTasks.removeValue(forKey: taskIdentifier)
              }
            }
          }
        }
      )
      
      self.processingTasks[taskIdentifier] = task
      return task
    }
  }
}
