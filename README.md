# Wotin - Work Time Tracker

A simple command-line time tracking tool written in Odin with SQLite backend.

## Features

- Track work time with start/stop commands
- Organize work by projects
- Tag entries for better categorization
- SQLite database storage at `~/.wotin/timetracking.db`
- Normalized database schema for efficient querying

## Building

```bash
nix develop
cd src
odin build . -out:../timer
```

## Usage

### Start tracking time

```bash
# Start tracking for a project
timer start myproject

# Start tracking with tags
timer start myproject --tags backend,urgent,client-a
```

### Stop tracking time

```bash
timer stop
```

## Database Schema

The application uses a normalized SQLite schema with the following tables:

- `projects` - Project definitions
- `tags` - Tag definitions
- `time_entries` - Time tracking entries with start/stop times
- `time_entry_tags` - Many-to-many relationship between entries and tags

See `schema.sql` for the complete schema definition.

## Querying Data

You can query the database directly with sqlite3:

```bash
# View all time entries with project names
sqlite3 ~/.wotin/timetracking.db "
  SELECT te.id, p.name, te.start_time, te.stop_time 
  FROM time_entries te 
  JOIN projects p ON te.project_id = p.id;
"

# View entries with their tags
sqlite3 ~/.wotin/timetracking.db "
  SELECT te.id, p.name, GROUP_CONCAT(t.name, ', ') as tags
  FROM time_entries te
  JOIN projects p ON te.project_id = p.id
  LEFT JOIN time_entry_tags tet ON te.id = tet.time_entry_id
  LEFT JOIN tags t ON tet.tag_id = t.id
  GROUP BY te.id;
"
```

## Future Backends

The architecture is designed to support multiple storage backends. A KDL (document-oriented) backend is planned for future implementation.
