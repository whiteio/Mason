//
//  BuildError.swift
//  Mason
//
//  Created by Chris White on 1/26/25.
//

import Foundation

enum BuildError: LocalizedError, CustomStringConvertible {
    case compilationFailed(String)
    case signingFailed(String)
    case launchFailed(String)
    case installationFailed(String)
    case cyclicDependency([String])
    
    var description: String {
        errorDescription ?? "Unknown build error"
    }
    
    var errorDescription: String? {
        switch self {
        case .compilationFailed(let msg):
            return "Compilation failed: \(msg)"
        case .signingFailed(let msg):
            return "Signing failed: \(msg)"
        case .launchFailed(let msg):
            return "Launch failed: \(msg)"
        case .installationFailed(let msg):
            return "Installation failed: \(msg)"
        case .cyclicDependency(let path):
            let cycle = path.map { "[\($0)]" }.joined(separator: " ➜ ")
            return "Cyclic dependency detected: \(cycle)"
        }
    }
}
