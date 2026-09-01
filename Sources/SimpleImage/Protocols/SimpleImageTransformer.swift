//
//  SimpleImageTransformer.swift
//  SimpleImage
//
//  Created by Faizan Durrani on 29/08/2026.
//

import Foundation

public protocol SimpleImageTransformer: Sendable {
  func transform(data: Data) async throws -> Data
}
