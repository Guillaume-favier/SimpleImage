//
//  SimpleImageProcessor.swift
//  SimpleImage
//
//  Created by Faizan Durrani on 29/08/2026.
//

import Foundation
import UIKit

public protocol SimpleImageProcessor: Sendable {
  var identifier: String { get }
  func process(image: UIImage) async throws -> UIImage
}
