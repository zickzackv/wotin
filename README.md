# wotin

**wotin** - A time tracking tool written in Odin, inspired by [Watson](https://github.com/TailorDev/Watson).

## About

wotin is a command-line time tracking application built with the [Odin programming language](https://odin-lang.org/). It's designed to help you track time spent on projects and tasks with a simple, efficient interface.

## Features (Planned)

- ⏱️ Start/stop time tracking for projects
- 🏷️ Tag entries for better organization
- 📊 Generate reports and statistics
- 💾 Local data storage (JSON-based)
- 🔄 Import/export functionality
- 🎯 Simple, intuitive CLI

## Prerequisites

To build and run wotin, you'll need:

- [Odin compiler](https://odin-lang.org/docs/install/) (latest stable version recommended)
- Git (for cloning the repository)

### Installing Odin

**Windows:**
1. Install Visual Studio Build Tools with C++ support
2. Clone the Odin repository: `git clone https://github.com/odin-lang/Odin`
3. Build Odin: `cd Odin && build.bat release`
4. Add Odin to your PATH

**Linux/macOS:**
1. Install LLVM/Clang
2. Clone the Odin repository: `git clone https://github.com/odin-lang/Odin`
3. Build Odin: `cd Odin && make release-native`
4. Add Odin to your PATH

For detailed installation instructions, see the [official Odin installation guide](https://odin-lang.org/docs/install/).

## Building

### Linux/macOS

```bash
# Debug build
./build.sh

# Release build
./build.sh release
```

### Windows

```cmd
REM Debug build
build.bat

REM Release build
build.bat release
```

Or build directly with Odin:

```bash
# Debug build
odin build src -out:build/wotin -debug

# Release build
odin build src -out:build/wotin -o:speed
```

## Usage

```bash
# Run the built binary
./build/wotin
```

## Project Structure

```
wotin/
├── src/
│   ├── main.odin      # Main entry point
│   ├── config.odin    # Configuration handling
│   └── types.odin     # Core data structures
├── build/             # Build output directory (gitignored)
├── build.sh           # Linux/macOS build script
├── build.bat          # Windows build script
├── .gitignore
└── README.md
```

## Development Roadmap

### Phase 1: Core Functionality
- [ ] Basic CLI structure
- [ ] Start/stop time tracking
- [ ] Project and tag management
- [ ] Local data persistence (JSON)

### Phase 2: Reporting
- [ ] Daily/weekly/monthly reports
- [ ] Time statistics per project
- [ ] Export to various formats

### Phase 3: Advanced Features
- [ ] Edit existing entries
- [ ] Delete entries
- [ ] Search and filter functionality
- [ ] Configuration file support

## Inspiration

This project is inspired by:
- [Watson](https://github.com/TailorDev/Watson) - Simple time tracking CLI
- The Odin philosophy of simplicity and performance

## Contributing

Contributions are welcome! This is a learning project, so feel free to:
- Report bugs
- Suggest features
- Submit pull requests
- Improve documentation

## License

TBD

## Resources

- [Odin Official Documentation](https://odin-lang.org/docs/)
- [Odin GitHub Repository](https://github.com/odin-lang/Odin)
- [Watson Documentation](https://tailordev.github.io/Watson/)
