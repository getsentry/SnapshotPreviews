//
//  FileNameUtils.swift
//  SnapshotPreviews
//
//  Created by  Cameron Cooke on 08/06/2026.
//

import Foundation

enum FileNameUtils {
  
  /// Accepts a pre-sanitized value, then converts it into a safe image filename with a .png extension.
  static func imageFileName(from value: String) -> String {
    "\(sanitize(value)).png"
  }
  
  private static func sanitize(_ value: String) -> String {
    var result = ""
    var lastWasUnderscore = false
    
    for c in value {
      if c.isLetter || c.isNumber || c == "." || c == "-" || c == "_" {
        result.append(c)
        lastWasUnderscore = false
      } else if !lastWasUnderscore {
        result.append("_")
        lastWasUnderscore = true
      }
    }
    
    result = result.trimmingCharacters(in: CharacterSet(charactersIn: "_.-"))
    
    return result.isEmpty ? "snapshot" : result
  }
}
