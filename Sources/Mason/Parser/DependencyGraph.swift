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
    
    func resolveDependencies(for module: String) throws -> [String] {
        var resolved: [String] = []
        var visited: Set<String> = []
        var recursionStack: Set<String> = []
        var pathStack: [String] = []
        
        try resolveWithCycleDetection(
            module,
            &resolved,
            &visited,
            &recursionStack,
            &pathStack
        )
        
        return resolved
    }
    
    private func resolveWithCycleDetection(
        _ module: String,
        _ resolved: inout [String],
        _ visited: inout Set<String>,
        _ recursionStack: inout Set<String>,
        _ pathStack: inout [String]
    ) throws {
        // If we've already fully processed this module, skip it
        guard !visited.contains(module) else { return }
        
        // Check for cycle
        if recursionStack.contains(module) {
            // Find where the cycle starts in the path
            if let cycleStart = pathStack.firstIndex(of: module) {
                var cycle = Array(pathStack[cycleStart...])
                cycle.append(module) // Complete the cycle
                throw BuildError.cyclicDependency(cycle)
            }
            return
        }
        
        // Add to recursion stack and path for cycle detection
        recursionStack.insert(module)
        pathStack.append(module)
        
        // Process dependencies
        if let dependencies = adjacencyList[module] {
            for dependency in dependencies {
                try resolveWithCycleDetection(
                    dependency,
                    &resolved,
                    &visited,
                    &recursionStack,
                    &pathStack
                )
            }
        }
        
        // Remove from recursion stack after processing
        recursionStack.remove(module)
        pathStack.removeLast()
        
        // Mark as visited and add to resolved list
        visited.insert(module)
        resolved.append(module)
    }
    
    func validateGraph() throws {
        // Validate all modules in the graph
        for module in adjacencyList.keys {
            var visited: Set<String> = []
            var recursionStack: Set<String> = []
            var pathStack: [String] = []
            try validateModule(
                module,
                &visited,
                &recursionStack,
                &pathStack
            )
        }
    }
    
    private func validateModule(
        _ module: String,
        _ visited: inout Set<String>,
        _ recursionStack: inout Set<String>,
        _ pathStack: inout [String]
    ) throws {
        // Check if this module is in the current recursion path
        if recursionStack.contains(module) {
            if let cycleStart = pathStack.firstIndex(of: module) {
                var cycle = Array(pathStack[cycleStart...])
                cycle.append(module)
                throw BuildError.cyclicDependency(cycle)
            }
            return
        }
        
        // If we've already validated this module, skip it
        if visited.contains(module) {
            return
        }
        
        recursionStack.insert(module)
        pathStack.append(module)
        
        // Validate all dependencies
        if let dependencies = adjacencyList[module] {
            for dependency in dependencies {
                // Verify the dependency exists
                guard adjacencyList[dependency] != nil else {
                    BuildLogger.error("Module '\(module)' depends on undefined module '\(dependency)'")
                    continue
                }
                
                try validateModule(
                    dependency,
                    &visited,
                    &recursionStack,
                    &pathStack
                )
            }
        }
        
        recursionStack.remove(module)
        pathStack.removeLast()
        visited.insert(module)
    }
}
