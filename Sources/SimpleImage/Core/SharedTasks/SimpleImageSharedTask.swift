//
//  SimpleImageSharedTask.swift
//  SimpleImage
//
//  Created by Faizan Durrani on 29/08/2026.
//

import Foundation
import UIKit

class SimpleImageSharedTask: @unchecked Sendable {
  enum State {
    case waiting(work: @isolated(any) @Sendable () async -> Void)
    case working(Task<Void, Never>)
    case finished(result: Result<ImageContainer, Error>)
    case cancelled
  }

  let request: URLRequest
  var isCancelled: Bool {
    self.lock.withLock {
      if case .cancelled = state { return true }
      return false
    }
  }

  nonisolated(unsafe) var state: State!
  private nonisolated(unsafe) var children: [UUID: SimpleImageTask]

  private let lock = NSLock()
  private let completionHandler:
    @Sendable (SimpleImageSharedTask, Result<ImageContainer, Error>) -> Void

  init(
    request: URLRequest,
    completionHandler:
      @escaping @Sendable (SimpleImageSharedTask, Result<ImageContainer, Error>) -> Void,
  ) {
    self.children = [:]
    self.request = request
    self.completionHandler = completionHandler
  }

  enum AttachResult {
    case attached
    case finished(Result<ImageContainer, Error>)
    case cancelled
  }

  func attach(task: SimpleImageTask) -> AttachResult {
    self.lock.withLock {
      switch self.state! {
      case .waiting(let work):
        self.children[task.id] = task
        self.state = .working(Task(operation: work))
        return .attached

      case .working:
        self.children[task.id] = task
        return .attached

      case .finished(let result):
        return .finished(result)

      case .cancelled:
        return .cancelled
      }
    }
  }

  func detach(task: SimpleImageTask) {
    var underlyingTask: Task<Void, Never>?
    var didCancel = false

    self.lock.withLock {
      self.children.removeValue(forKey: task.id)

      guard self.children.isEmpty else { return }

      switch self.state! {
      case .waiting:
        self.state = .cancelled
        didCancel = true

      case .working(let task):
        self.state = .cancelled
        underlyingTask = task
        didCancel = true

      case .finished, .cancelled:
        break
      }
    }

    guard didCancel else { return }

    underlyingTask?.cancel()
    self.completionHandler(self, .failure(CancellationError()))
  }

  func reportProgress(_ fraction: Double) {
    let subscribers = lock.withLock { Array(children.values) }
    subscribers.forEach { $0.reportProgress(fraction) }
  }

  func finish(with result: Result<ImageContainer, Error>) {
    self.lock.lock()
    guard case .working = self.state else {
      self.lock.unlock()
      return
    }

    let children = self.children
    self.state = .finished(result: result)
    self.children.removeAll()

    self.lock.unlock()

    self.completionHandler(self, result)
    for (_, child) in children {
      child.processImageResult(result)
    }
  }
}
