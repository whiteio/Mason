//
//  BuildError.swift
//  Mason
//
//  Created by Chris White on 1/26/25.
//

enum BuildError: Error {
    case compilationFailed(String)
    case signingFailed(String)
    case launchFailed(String)
    case installationFailed(String)
}
