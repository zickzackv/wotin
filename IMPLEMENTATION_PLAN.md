# Implementation Plan - Wotin CLI Interface Enhancement

## Progress Tracker

- [x] Task 1: Add frame ID support to database schema ✅
- [x] Task 2: Implement Watson-style argument parser ✅
- [x] Task 3: Implement time shortcut resolution ✅
- [x] Task 4: Implement `status` command ✅
- [x] Task 5: Implement `cancel` command ✅
- [ ] Task 6: Implement `restart` command
- [x] Task 7: Implement `frames` command ✅
- [x] Task 8: Implement `log` command ✅
- [x] Task 9: Implement `report` command ✅
- [ ] Task 10: Implement `aggregate` command
- [ ] Task 11: Implement `remove` command
- [ ] Task 12: Implement `change` command
- [ ] Task 13: Implement `edit` command
- [ ] Task 14: Implement `rename` command
- [ ] Task 15: Implement `projects` and `tags` commands
- [ ] Task 16: Implement `current` command
- [x] Task 17: Update `start` command with Watson syntax and auto-stop ✅
- [x] Task 18: Update `stop` command with Watson features ✅
- [x] Task 19: Implement JSON output formatter ✅
- [ ] Task 20: Update help system and command documentation

## Completed: 12/20 tasks (60%)

### Summary

We've successfully implemented the core Watson-inspired time tracking functionality:

**✅ Infrastructure (3 tasks)**
- Frame ID generation and storage
- Watson-style argument parser (+tag syntax)
- Time shortcut resolution (--today, --week, etc.)

**✅ Core Commands (6 tasks)**
- status - Show current activity
- cancel - Delete running activity
- frames - List all frame IDs
- log - Detailed activity list with JSON
- report - Aggregated time breakdown with JSON
- Enhanced start/stop with auto-stop

**✅ Output Formatting (1 task)**
- JSON formatter for log and report

**⏳ Remaining (8 tasks)**
- restart/continue command
- remove, change, edit commands
- rename command
- aggregate command
- Enhanced projects/tags listing
- current command
- Help system

The tool is **fully functional** for daily time tracking with Watson-style syntax and auto-stop behavior.
- [ ] Task 4: Implement `status` command
- [ ] Task 5: Implement `cancel` command
- [ ] Task 6: Implement `restart` command
- [ ] Task 7: Implement `frames` command
- [ ] Task 8: Implement `log` command
- [ ] Task 9: Implement `report` command
- [ ] Task 10: Implement `aggregate` command
- [ ] Task 11: Implement `remove` command
- [ ] Task 12: Implement `change` command
- [ ] Task 13: Implement `edit` command
- [ ] Task 14: Implement `rename` command
- [ ] Task 15: Implement `projects` and `tags` commands
- [ ] Task 16: Implement `current` command
- [ ] Task 17: Update `start` command with Watson syntax and auto-stop
- [ ] Task 18: Update `stop` command with Watson features
- [ ] Task 19: Implement JSON output formatter
- [ ] Task 20: Update help system and command documentation

## Problem Statement
Wotin currently has basic `start`, `stop`, `list`, and `add` commands with flag-based syntax. We need to expand it into a comprehensive time tracking CLI with Watson-inspired features, supporting both Watson's `+tag` syntax and flag-based arguments, with frame IDs for easy reference.

## Requirements
1. **Command syntax**: Watson style with `+tag` syntax, but also support `--tags` flag for backward compatibility
2. **Commands**: Comprehensive set including core tracking, reporting, and management commands
3. **Output formats**: Plain text and JSON
4. **Time handling**: Full Watson-style with `--at`, `--from/--to`, and shortcuts (`--today`, `--week`, etc.)
5. **Frame IDs**: Short hash IDs (like Watson's `f1c4815`) for easy reference
6. **Auto-stop**: Always stop current activity when starting a new one (no configuration needed)
7. **Editing**: Support both direct editor-based editing and in-place modifications
8. **Scope**: Focus on core tracking/reporting first, skip remote sync features

## Architecture Changes
1. Add `frame_id` column to `time_entries` table (7-char hash)
2. Create command parser supporting both positional args with `+tags` and flags
3. Implement time shortcut resolution (`--today`, `--week`, etc.)
4. Add JSON output formatter alongside existing plain text
5. Implement frame-based operations (edit, remove, restart by ID)

## Command Structure
```
timer <command> [args] [+tags] [--flags]
```

---

## Task Details

### Task 1: Add frame ID support to database schema
**Status**: Not Started

**Objective**: Modify database schema to include unique frame IDs for each time entry

**Implementation**:
- Add migration to add `frame_id TEXT UNIQUE` column to `time_entries` table
- Create function to generate 7-character hash IDs (similar to git short hashes)
- Update `start_tracking` and `add_time_entry` to generate and store frame IDs
- Add index on `frame_id` for fast lookups
- Create `get_entry_by_frame_id` function

**Testing**: Verify frame IDs are unique, retrievable, and persist correctly

**Demo**: Start/stop activities and verify each has a unique frame ID in the database

---

### Task 2: Implement Watson-style argument parser
**Status**: Not Started

**Objective**: Create parser that handles positional args, `+tag` syntax, and flags simultaneously

**Implementation**:
- Create `parse_args` function that separates positional args, tags (starting with `+`), and flags
- Support both `project +tag1 +tag2` and `project --tags tag1,tag2` syntax
- Return structured data: `{project: string, tags: []string, flags: map[string]string}`
- Handle edge cases (tags without `+`, mixed syntax)

**Testing**: Parse various command combinations and verify correct extraction

**Demo**: Parse example commands and print parsed structure

---

(Continue with remaining tasks...)
