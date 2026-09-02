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
  
  public func imageData(
    for request: URLRequest,
    progressHandler: @escaping @Sendable (Double) -> Void
  ) async throws -> Data {
    var (byteStream, response) = try await self.urlSession.bytes(for: request)
    
    let expectedContentLength = Int(response.expectedContentLength)
    var data = Data(capacity: expectedContentLength)
    progressHandler(0)
    
    for try await byte in byteStream {
      data.append(byte)
      progressHandler(Double(data.count)/Double(expectedContentLength))
    }
    
    return data
  }
}
