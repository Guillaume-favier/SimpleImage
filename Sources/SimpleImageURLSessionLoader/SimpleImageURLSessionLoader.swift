//
//  SimpleImageURLSessionLoader.swift
//  SimpleImage
//
//  Created by Faizan Durrani on 29/08/2026.
//

import Foundation
import SimpleImage

public final class SimpleImageURLSessionLoader: SimpleImageLoader {
  public let urlSession: URLSession
  
  public init(urlSession: URLSession) {
    self.urlSession = urlSession
  }
  
  public func imageData(for request: URLRequest) async throws -> Data {
    try await self.urlSession.data(for: request).0
  }
}
