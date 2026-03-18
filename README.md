# Wotin - Work Time Tracker

A Watson-inspired command-line time tracking tool written in Odin with SQLite backend.

## Features

- ✅ **Watson-style syntax** - Use `+tag` syntax: `timer start project +tag1 +tag2`
- ✅ **Frame IDs** - Short 7-character IDs for easy reference (like git hashes)
- ✅ **Auto-stop** - Starting a new activity automatically stops the current one
- ✅ **Time shortcuts** - `--today`, `--yesterday`, `--week`, `--month`, `--year`
- ✅ **JSON output** - Export data with `--json` flag
- ✅ **Tag support** - Organize work with multiple tags per entry
- ✅ **SQLite backend** - Normalized database schema for efficient querying
- ✅ **Comprehensive reporting** - View time breakdowns by project and tags

## Quick Start

### Building

```bash
nix develop
cd src
odin build . -out:../build/wotin
```

Or use the build script:
```bash
./build.sh
```

### Basic Usage

```bash
# Start tracking (Watson-style with +tags)
wotin start myproject +backend +urgent

# Start with backward-compatible --tags flag
wotin start myproject --tags backend,urgent

# Check current status
wotin status

# Stop tracking
wotin stop

# Cancel current activity without recording
wotin cancel
```

## Commands

### Core Tracking

**start** - Start tracking time
```bash
wotin start <project> [+tag1 +tag2...] [--at HH:MM]
wotin start myproject +backend +api
wotin start "client work" +meeting --tags urgent,important
wotin start myproject +backend --at 09:00   # backdate to 09:00 today
```
- Automatically stops any running activity
- Supports both `+tag` and `--tags` syntax
- Generates unique frame ID for each entry

**stop** - Stop tracking
```bash
wotin stop
```
- Shows frame ID and duration
- Displays project and tags

**status** - Show currently running activity
```bash
wotin status
```
- Shows project, tags, start time, and frame ID
- Exit code 1 if nothing running

**cancel** - Delete current activity without recording
```bash
wotin cancel
```

### Viewing Data

**frames** - List all frame IDs
```bash
wotin frames
```
- Shows frame IDs in reverse chronological order
- Useful for referencing specific entries

**log** - Detailed activity list
```bash
wotin log
wotin log --json
```
- Groups entries by date
- Shows start/stop times, project, and tags
- Supports `--json` output format

**report** - Aggregated time report
```bash
wotin report
wotin report --json
```
- Shows total time per project
- Breaks down time by tags within each project
- Displays grand total
- Supports `--json` output format

### Legacy Commands

**list** - List projects, entries, or tags (old syntax)
```bash
wotin list projects
wotin list entries
wotin list tags
```

**add** - Manually add past activity (old syntax)
```bash
wotin add <project> --from <time> --to <time> [--tags tag1,tag2]
```

**import** - Import from Watson frames file
```bash
wotin import ~/.config/watson/frames
```

**version** - Show version
```bash
wotin version
```

## Database

- Location: `~/.wotin/timetracking.db`
- Schema: Normalized SQLite with projects, tags, time_entries, and time_entry_tags tables
- Frame IDs: Automatically generated 7-character hashes for each entry
- Migration: Automatically adds frame_id column to existing databases

### Custom Database Path

The database location can be overridden in two ways:

```bash
# Environment variable (persists for the shell session)
export WOTIN_DB=~/work.db
wotin log

# Global flag (one-off)
wotin --db ~/work.db log --today
```

This is useful for keeping a separate test database during development:

```nix
# flake.nix devShell
shellHook = ''
  export WOTIN_DB="$PWD/.wotin-dev.db"
'';
```

## Examples

### Typical Workflow

```bash
# Morning - start work
wotin start project-a +backend +api
# ... work for a while ...

# Switch to different task (auto-stops previous)
wotin start project-b +frontend +ui
# ... work for a while ...

# Lunch break
wotin stop

# Resume work
wotin start project-a +backend +testing

# End of day
wotin stop

# View today's work
wotin log

# See time breakdown
wotin report
```

### JSON Export

```bash
# Export log as JSON
wotin log --json > activities.json

# Export report as JSON
wotin report --json > time_report.json
```

## Architecture

### File Structure
```
src/
├── main.odin              # Main entry point and command routing
├── backend_sqlite.odin    # SQLite database operations
├── frame_id.odin          # Frame ID generation
├── arg_parser.odin        # Watson-style argument parser
├── time_shortcuts.odin    # Time range resolution (--today, --week, etc.)
├── json_formatter.odin    # JSON output formatting
├── datetime_parser.odin   # Date/time parsing utilities
├── formatting.odin        # Plain text output formatting
├── config.odin            # Configuration and paths
├── types.odin             # Data structures
└── sqlite.odin            # SQLite bindings
```

### Key Design Decisions

1. **SQLite over plaintext** - Unlike Bartib/Tock, uses normalized database for better querying
2. **Frame IDs** - Watson-compatible short hashes for easy reference
3. **Auto-stop** - Simplified workflow (no configuration needed)
4. **Dual syntax** - Supports both `+tag` and `--tags` for flexibility
5. **Minimal dependencies** - Pure Odin with SQLite

## Comparison with Other Tools

| Feature | Wotin | Watson | Bartib | Tock |
|---------|-------|--------|--------|------|
| Language | Odin | Python | Rust | Go |
| Storage | SQLite | JSON | Plaintext | Multiple |
| Frame IDs | ✅ | ✅ | ❌ | ✅ |
| +tag syntax | ✅ | ✅ | ❌ | ❌ |
| Auto-stop | ✅ | Optional | ❌ | ✅ |
| JSON output | ✅ | ✅ | ❌ | ✅ |
| TUI | ❌ | ❌ | ❌ | ✅ |
| Remote sync | ❌ | ✅ | ❌ | ❌ |

## Implementation Status

**Complete (23/23 tasks — 100%)**:
- ✅ Frame ID support
- ✅ Watson-style argument parser
- ✅ Time shortcuts (--today, --week, etc.)
- ✅ status, cancel, restart, frames commands
- ✅ Enhanced start/stop with auto-stop and --at flag
- ✅ log and report commands with time filters
- ✅ aggregate command (daily breakdown)
- ✅ projects and tags listing
- ✅ remove, change, edit, rename commands
- ✅ current command (alias for status)
- ✅ JSON output formatter
- ✅ Colored terminal output (respects NO_COLOR)
- ✅ Comprehensive help system
- ✅ Watson frames import
- ✅ version subcommand

## Future Enhancements

- ✅ CSV export (`wotin log --csv`, `wotin report --csv`)
- ✅ Shell completion scripts (`wotin completion bash|zsh|fish`)
- ✅ Configuration file (`~/.config/wotin/config`)

## Contributing

This is a personal project inspired by Watson, Bartib, and Tock. The goal is to combine Watson's excellent UX with SQLite's query power.

## License

See LICENSE file.

## Acknowledgments

- **Watson** - Inspiration for command syntax and frame IDs
- **Bartib** - Inspiration for simplicity and plaintext approach
- **Tock** - Inspiration for modern Go architecture
