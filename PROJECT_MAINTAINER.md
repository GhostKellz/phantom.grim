# phantom.grim - Project Maintainer Guide

## Overview

### 🏗️ Architecture Status
```
✅ Core Infrastructure: COMPLETE
✅ Configuration System: COMPLETE
✅ Plugin Loading: BASIC (needs lifecycle)
🔄 Motion Engine: IN PROGRESS
🔄 Plugin Ecosystem: PARTIAL
🔄 Testing: MINIMAL
```

---

## Architecture

### Core Components

#### 1. **Plugin Loader** (`src/core/plugin_loader.zig`)
- **Purpose**: HTTP-based plugin fetching and management
- **Dependencies**: zhttp, zsync
- **Status**: HTTP fetching implemented, needs lifecycle management
- **Key Functions**:
  - `fetchPlugin()`: Downloads plugins from registry
  - `loadPlugin()`: Loads plugin into runtime (placeholder)

#### 2. **Ghostlang Runtime** (`src/core/ghostlang_runtime.zig`)
- **Purpose**: Embedded scripting engine for .gza config files
- **Dependencies**: ghostlang
- **Status**: Core functions implemented and working
- **Built-in Functions**:
  - `print(value)`: Debug output
  - `set(key, value)`: Configuration setting
  - `map(mode, key, command)`: Key mapping
  - `autocmd(event, pattern, callback)`: Auto-command registration
  - `require(module)`: Module loading

#### 3. **Config Manager** (`src/core/config_manager.zig`)
- **Purpose**: Hierarchical configuration loading and management
- **Dependencies**: flare, ghostlang_runtime
- **Status**: Working with .gza file loading
- **Key Functions**:
  - `loadConfiguration()`: Main config loading entry point
  - `loadDefaults()`: Loads runtime/defaults/*.gza files
  - `get()`: Configuration value retrieval

#### 4. **Main Entry Point** (`src/main.zig`)
- **Purpose**: Application initialization and orchestration
- **Status**: Successfully initializes all systems
- **Flow**:
  1. Initialize allocator and logging
  2. Create config manager
  3. Load configuration
  4. Initialize plugin loader (placeholder)
  5. Start main loop (placeholder)

### Directory Structure
```
phantom.grim/
├── src/
│   ├── main.zig              # Application entry point
│   ├── root.zig              # Module exports
│   └── core/                 # Core components
│       ├── plugin_loader.zig # Plugin management
│       ├── ghostlang_runtime.zig # Scripting engine
│       └── config_manager.zig # Configuration system
├── runtime/
│   └── defaults/             # Default configuration files
│       ├── options.gza       # Editor options
│       ├── keymaps.gza       # Key bindings
│       └── autocmds.gza      # Auto commands
├── plugins/
│   └── core/                 # Core plugins
│       ├── file-tree.gza     # File tree plugin
│       └── fuzzy-finder.gza  # Fuzzy finder plugin
├── build.zig                 # Build configuration
└── build.zig.zon            # Dependencies
```

---

## Dependencies

### Core Dependencies (build.zig.zon)
- **zsync**: Async runtime for background operations
- **ghostlang**: Embedded scripting language
- **grove**: Tree-sitter integration for syntax parsing
- **zlog**: Structured logging
- **zhttp**: HTTP client for plugin fetching
- **flare**: Configuration management

### Build Requirements
- **Zig**: 0.16.0-dev or later
- **Tree-sitter**: Integrated via grove
- **C Compiler**: For Tree-sitter native components

### Adding Dependencies
```bash
zig fetch --save <dependency-url>
# Update build.zig to include the module
```

---

## Key Files and Their Purpose

### Configuration Files
- **`runtime/defaults/options.gza`**: Default editor options (set() calls)
- **`runtime/defaults/keymaps.gza`**: Default key bindings (map() calls)
- **`runtime/defaults/autocmds.gza`**: Default auto-commands (autocmd() calls)

### Important Notes
- **Ghostlang Syntax**: No `--` comments, use function call syntax
- **String Literals**: Double quotes supported
- **Function Calls**: Standard syntax `func(arg1, arg2)`

---

## Development Guidelines

### Code Style
- **Zig Standards**: Follow official Zig style guide
- **Documentation**: Comprehensive doc comments for public APIs
- **Error Handling**: Use Zig's error union types consistently
- **Memory Management**: Explicit allocator usage, no leaks

### Testing
- **Unit Tests**: Zig's built-in testing framework
- **Integration Tests**: End-to-end config loading tests
- **Performance Tests**: Benchmark critical paths

### Git Workflow
- **Branching**: Feature branches from main
- **Commits**: Clear, descriptive commit messages
- **PRs**: Comprehensive description and testing

---

## Known Issues and Challenges

### 1. Memory Leaks
- **Issue**: flare.Config not properly deinitialized
- **Impact**: Memory leak on shutdown
- **Fix**: Implement proper deinit in ConfigManager

### 2. Plugin Lifecycle
- **Issue**: Plugin loading is placeholder implementation
- **Impact**: No actual plugin execution
- **Fix**: Implement plugin lifecycle management

### 3. Motion Engine
- **Issue**: Harvest/Reap motions not implemented
- **Impact**: Missing core Grim integration
- **Fix**: Use grove treesitter for syntax-aware motions

### 4. Error Handling
- **Issue**: Some error paths not fully handled
- **Impact**: Potential crashes on malformed config
- **Fix**: Comprehensive error handling throughout

---

## Build and Run

### Building
```bash
zig build
```

### Running
```bash
./zig-out/bin/phantom_grim
```

### Testing
```bash
zig build test
```

### Development Build
```bash
zig build -Doptimize=Debug
```

---

## Deployment and Distribution

### Target Platforms
- **Linux**: Primary target (x86_64)
- **macOS**: Secondary target
- **Windows**: Future consideration

### Packaging
- **Binary Distribution**: Static binaries with all dependencies
- **Plugin Registry**: HTTP-based plugin hosting
- **Configuration**: User config in `~/.config/phantom.grim/`

### Installation
```bash
# Download binary
# Place in PATH
# Create config directory
mkdir -p ~/.config/phantom.grim
```

---

## Contributing

### For AI Agents
1. **Read This Document**: Understand project vision and current status
2. **Check TODO List**: Prioritize based on project goals
3. **Follow Architecture**: Maintain modular design
4. **Test Changes**: Ensure builds pass and functionality works
5. **Update Documentation**: Keep this guide current

### Priority Order
1. **Motion Engine**: Core Grim differentiation
2. **Plugin System**: Complete ecosystem
3. **Memory Management**: Fix leaks and optimize
4. **Testing**: Comprehensive test coverage
5. **Documentation**: User and developer docs

### Communication
- **Issues**: Use GitHub issues for bugs/features
- **Discussions**: Architecture decisions and planning
- **PRs**: Code review and integration

---

## Future Roadmap

### Phase 1: Core Completion (Current)
- Motion engine implementation
- Plugin lifecycle management
- Memory leak fixes
- Comprehensive testing

### Phase 2: Ecosystem Growth
- Plugin registry development
- grim-tutor implementation
- Performance optimizations
- Cross-platform support

### Phase 3: Production Ready
- Stable API definition
- Documentation completion
- Package management
- Community building

---

## Contact and Resources

### Project Links
- **Repository**: https://github.com/ghostkellz/phantom.grim
- **Issues**: GitHub Issues
- **Discussions**: GitHub Discussions

### Dependencies
- **Zig**: https://ziglang.org/
- **Ghostlang**: https://github.com/ghostlang/ghostlang
- **Grove**: https://github.com/ghostkellz/grove
- **Grim Editor**: [Grim repository]

### Related Projects
- **LazyVim**: Inspiration for configuration approach
- **Neovim**: Ecosystem reference
- **Helix**: Modern editor architecture reference

---

*This document is maintained by the phantom.grim development team. Last updated: October 5, 2025*</content>
<parameter name="filePath">/data/projects/phantom.grim/PROJECT_MAINTAINER.md