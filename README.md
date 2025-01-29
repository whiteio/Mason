# Mason - A Swift Build System for iOS

Mason is a modern, high-performance build system for iOS applications, designed to handle modular applications with sophisticated dependency graphs. It features parallel compilation, intelligent caching, and flexible configuration options.

## Features

### Parallel Building
- Smart dependency graph analysis for optimal build ordering
- Level-based parallel compilation of independent modules
- Thread-safe implementation using Swift actors
- Real-time build statistics and timing information

### Intelligent Caching
- Module-level caching for faster incremental builds
- Hash-based cache invalidation
- Efficient cache restoration
- Support for clean builds when needed

### Flexible Configuration
- YAML-based project configuration
- Customizable Swift version per project
- Configurable Info.plist management
- Module dependency specification

## Getting Started

### Installation

```bash
git clone [repository-url]
cd mason
swift build -c release
cp .build/release/mason /usr/local/bin/
```

### Project Configuration

Create an `app.yml` file in your project root:

```yaml
app-name: YourApp
bundle-id: com.example.yourapp
source-dir: Sources
resources-dir: Resources
deployment-target: "15.0"
swift-version: "5.9"  # Optional, defaults to "5"
modules:
  - ModuleA
  - ModuleB

plist:
  version: "1.0.0"
  build-number: "1"
  info-plist:
    launch-screen: true
    required-device-capabilities:
      - arm64
      - metal
    supported-orientations:
      - UIInterfaceOrientationPortrait
    custom-entries:
      UIViewControllerBasedStatusBarAppearance: false
```

### Module Configuration

For each module, create a `module.yml` file:

```yaml
module-name: ModuleA
dependencies:
  - ModuleB
  - ModuleC
source-dir: Sources
resources-dir: Resources
```

### Usage

Build the entire app:
```bash
mason build --source /path/to/your/project
```

Build a specific module:
```bash
mason build --source /path/to/your/project --module ModuleA
```

Clean build:
```bash
mason build --source /path/to/your/project --clean
```

## Project Structure

```
YourApp/
├── app.yml
├── Sources/
│   ├── AppDelegate.swift
│   └── SceneDelegate.swift
├── ModuleA/
│   ├── module.yml
│   └── Sources/
│       └── ModuleACode.swift
└── ModuleB/
    ├── module.yml
    └── Sources/
        └── ModuleBCode.swift
```

## Build Process

1. **Configuration Loading**
   - Parse YAML configuration files
   - Validate project structure
   - Resolve module dependencies

2. **Dependency Analysis**
   - Build dependency graph
   - Determine optimal build order
   - Group modules by dependency level

3. **Parallel Building**
   - Build independent modules concurrently
   - Respect dependency ordering
   - Track build progress and timing

4. **Caching**
   - Calculate module hashes
   - Cache build artifacts
   - Restore cached modules when possible

5. **Final Steps**
   - Link modules
   - Generate final executable
   - Install to simulator
   - Launch application

## Performance

Mason utilizes parallel building to significantly reduce build times:

- Modules at the same dependency level build concurrently
- Build time statistics track parallelization benefits
- Cache system reduces unnecessary recompilation

Example timing output:
```
Level 1 build statistics:
- Modules built: 7
- Maximum concurrent builds: 7
- Average build time: 2.28s
- Total wall clock time: 2.34s
- Time saved via parallelization: 13.63s
```

## Requirements

- Xcode 14.0+
- Swift 5.5+
- iOS 15.0+ deployment target
- macOS 12.0+ for development

## Credits

Created by Chris White
