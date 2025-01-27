//
//  DependencyGraph.swift
//  mason
//
//  Created by Chris White on 1/27/25.
//

import Foundation

class DependencyGraph {
    var adjacencyList: [String: [String]] = [:]

    func addModule(_ module: String, dependencies: [String]?) {
        adjacencyList[module] = dependencies ?? []
    }

    func resolveDependencies(for module: String) -> [String] {
        var resolved: [String] = []
        var visited: Set<String> = []
        resolve(module, &resolved, &visited)
        return resolved
    }

    private func resolve(_ module: String, _ resolved: inout [String], _ visited: inout Set<String>) {
        guard !visited.contains(module) else { return }
        visited.insert(module)

        if let dependencies = adjacencyList[module] {
            for dependency in dependencies {
                resolve(dependency, &resolved, &visited)
            }
        }

        resolved.append(module)
    }
}
