//
//  String+SHA1.swift
//  SimpleImage
//
//  Created by Faizan Durrani on 29/08/2026.
//

import Foundation
import CryptoKit

private let sha1HexChars: [UInt8] = Array("0123456789abcdef".utf8)

extension String {
    /// Calculates SHA1 from the given string and returns its hex representation.
    ///
    /// ```swift
    /// print("http://test.com".sha1)
    /// // prints "50334ee0b51600df6397ce93ceed4728c37fee4e"
    /// ```
    var sha1: String {
        let digest = Insecure.SHA1.hash(data: Data(self.utf8))
        let hexCount = Insecure.SHA1Digest.byteCount * 2
        let bytes = [UInt8](unsafeUninitializedCapacity: hexCount) { buffer, count in
            var i = 0
            for byte in digest {
                buffer[i] = sha1HexChars[Int(byte >> 4)]
                buffer[i &+ 1] = sha1HexChars[Int(byte & 0x0F)]
                i &+= 2
            }
            count = hexCount
        }
        return String(decoding: bytes, as: UTF8.self)
    }
}
