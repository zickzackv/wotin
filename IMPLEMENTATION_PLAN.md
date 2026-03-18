# Implementation Plan - Wotin CLI Interface Enhancement

## Progress Tracker

- [x] Task 1: Add frame ID support to database schema ✅
- [x] Task 2: Implement Watson-style argument parser ✅
- [x] Task 3: Implement time shortcut resolution ✅
- [x] Task 4: Implement `status` command ✅
- [x] Task 5: Implement `cancel` command ✅
- [x] Task 6: Implement `restart` command ✅
- [x] Task 7: Implement `frames` command ✅
- [x] Task 8: Implement `log` command ✅
- [x] Task 9: Implement `report` command ✅
- [x] Task 10: Implement `aggregate` command ✅
- [x] Task 11: Implement `remove` command ✅
- [x] Task 12: Implement `change` command ✅
- [x] Task 13: Implement `edit` command ✅
- [x] Task 14: Implement `rename` command ✅
- [x] Task 15: Implement `projects` and `tags` commands ✅
- [x] Task 16: Implement `current` command (alias for status) ✅
- [x] Task 17: Update `start` command with Watson syntax and auto-stop ✅
- [x] Task 18: Update `stop` command with Watson features ✅
- [x] Task 19: Implement JSON output formatter ✅
- [x] Task 20: Update help system and command documentation ✅
- [x] Task 21: Colored terminal output via `core:terminal/ansi` ✅
- [x] Task 22: `--at` flag for `start` command ✅
- [x] Task 23: `version` subcommand, bump to v0.1.1 ✅

## Completed: 23/23 tasks (100%)

### Summary

All planned features are implemented and the tool is ready for daily use.

**✅ Infrastructure (3 tasks)**
- Frame ID generation and storage
- Watson-style argument parser (+tag syntax)
- Time shortcut resolution (--today, --week, etc.)

**✅ Core Commands (10 tasks)**
- status / current — show running activity
- cancel — delete running activity without saving
- restart — resume last stopped activity
- frames — list all frame IDs
- log — detailed activity list with JSON and time filters
- report — aggregated time breakdown with JSON and time filters
- aggregate — daily breakdown per project
- projects / tags — list with usage stats
- Enhanced start (auto-stop, +tag syntax, --at flag)
- Enhanced stop (frame ID display)

**✅ Management Commands (4 tasks)**
- remove — delete entry by frame ID
- change — update project/tags of an entry
- edit — open entry in $EDITOR as JSON
- rename — bulk rename project or tag

**✅ Output & UX (4 tasks)**
- JSON formatter for log, report, aggregate
- Colored terminal output (respects NO_COLOR, TTY detection)
- Comprehensive help system
- Watson frames import

**✅ Extras**
- `--at` flag for backdated start
- `version` subcommand
- `import` command for Watson frames migration
