//
//  SimpleImageLoader.swift
//  SimpleImage
//
//  Created by Faizan Durrani on 29/08/2026.
//

import Foundation
import UIKit

public protocol SimpleImageLoader: Sendable {
  func imageData(for request: URLRequest) async throws -> Data
}
