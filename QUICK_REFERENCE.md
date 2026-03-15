# Wotin Quick Reference

## Essential Commands

```bash
# Start tracking
wotin start <project> +tag1 +tag2

# Check status
wotin status

# Stop tracking
wotin stop

# Cancel without recording
wotin cancel
```

## Viewing Data

```bash
# List all frame IDs
wotin frames

# View activity log
wotin log
wotin log --json

# View time report
wotin report
wotin report --json
```

## Examples

```bash
# Start work with tags
wotin start myproject +backend +urgent +api

# Auto-stop by starting new activity
wotin start anotherproject +frontend

# View today's activities
wotin log

# See time breakdown
wotin report

# Export as JSON
wotin log --json > activities.json
```

## Tag Syntax

```bash
# Watson style (preferred)
wotin start project +tag1 +tag2 +tag3

# Backward compatible
wotin start project --tags tag1,tag2,tag3

# Mixed (both work)
wotin start project +tag1 --tags tag2,tag3
```

## Features

- ✅ Auto-stop when starting new activity
- ✅ Frame IDs for easy reference
- ✅ JSON export for scripting
- ✅ SQLite backend for powerful queries
- ✅ Tag-based organization
- ✅ Time breakdown by project and tags

## Database Location

`~/.wotin/timetracking.db`

## Direct SQL Queries

```bash
# View all entries
sqlite3 ~/.wotin/timetracking.db "SELECT * FROM time_entries"

# View with frame IDs
sqlite3 ~/.wotin/timetracking.db "SELECT frame_id, start_time, stop_time FROM time_entries"
```
