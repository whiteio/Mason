//
//  BuildError.swift
//  Mason
//
//  Created by Chris White on 1/26/25.
//

enum BuildError: Error {
    case compilationFailed(String)
    case resourceProcessingFailed(String)
    case bundleCreationFailed(String)
    case ipaCreationFailed(String)
    case invalidPath(String)
    case signingFailed(String)
    case launchFailed(String)
    case installationFailed(String)
}
