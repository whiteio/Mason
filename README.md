# Mason

A minimal, parallel build system for iOS apps written in Swift.

## Features

- Parallel module compilation with dependency-aware scheduling
- Incremental builds with hash-based caching
- YAML configuration for projects and modules
- Real-time build statistics

Currently it only supports the simulator, but I'm hoping to expand upon it since it's pretty basic at the moment.

## Installation

```bash
git clone [repository-url]
cd mason
swift build -c release
cp .build/release/mason /usr/local/bin/
```

## Configuration

See the example in `Example0/`

### Project Configuration (app.yml)

```yaml
app-name: Example0
bundle-id: com.example.example0
source-dir: Sources
resources-dir: Resources
deployment-target: 15.0
swift-version: 6
modules:
  - ModuleA
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

### Module Configuration (module.yml)

```yaml
module-name: ModuleA
type: library
dependencies:
  - ModuleB
  - ModuleC
  - ModuleD
source-dir: ModuleA/Sources
resources-dir: ModuleA/Resources
```

## Usage

Build project:
```bash
mason build --source /path/to/project
```

E.g.
```bash
mason build --source Example0
```

Build single module:
```bash
mason build --source /path/to/project --module ModuleA
```

Clean build:
```bash
mason build --source /path/to/project --clean
```

## Project Structure

```
ProjectRoot/
├── app.yml
├── Sources/
│   └── App/
├── ModuleA/
│   ├── module.yml
│   └── Sources/
└── ModuleB/
    ├── module.yml
    └── Sources/
```

## Requirements

- Xcode 15.0+
- Swift 5.9+
- iOS 15.0+ deployment target
- macOS 13.0+ for development

## License

MIT

## Contributing

Pull requests welcome!
