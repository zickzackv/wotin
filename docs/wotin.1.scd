wotin(1)

# NAME

wotin - work time tracker

# SYNOPSIS

*wotin* [--db _path_] _command_ [_args_]

# DESCRIPTION

wotin is a command-line time tracker with Watson-compatible syntax. It stores
entries in a local SQLite database and identifies each frame by a short 7-character ID.

# COMMANDS

## Tracking

*start* _project_ [+_tag_...] [--at _HH:MM_]
	Start tracking time for _project_. Automatically stops any running activity.
	Tags can be specified with the *+tag* prefix or via *--tags* _t1,t2_.
	Use *--at* to backdate the start time.

*stop*
	Stop the currently running activity and record it.

*cancel*
	Delete the current activity without saving it.

*restart*
	Restart the last stopped activity.

*status*, *current*
	Show the currently running activity. Exits with code 1 if nothing is running.

## Viewing

*log* [--json|--csv] [_time-filter_]
	List recorded activities grouped by date.

*report* [--json|--csv] [_time-filter_]
	Show aggregated time per project with tag breakdown and grand total.

*aggregate* [--json] [_time-filter_]
	Show daily time breakdown per project.

*frames*
	List all frame IDs in reverse chronological order.

*projects*
	List all projects with their total tracked time.

*tags*
	List all tags with their usage count.

## Management

*remove* _frame_id_
	Delete the entry identified by _frame_id_.

*change* _frame_id_ [--project _name_] [+_tag_...]
	Update the project and/or tags of an existing entry.

*edit* _frame_id_
	Open an entry in *$EDITOR* to adjust its start and stop times.

*rename* project|tag _old_ _new_
	Rename a project or tag across all entries.

*add* _project_ --from _time_ --to _time_ [+_tag_...]
	Manually add a past activity. Time format: _HH:MM_ or _YYYY-MM-DD HH:MM_.

*import* _path_
	Import entries from a Watson frames file.

*completion* bash|zsh|fish
	Print a shell completion script for the given shell.

*version*
	Print the version string.

# OPTIONS

*--db* _path_
	Use _path_ as the SQLite database file. Overrides *WOTIN_DB*.

## Time filters (for log, report, aggregate)

*--today*, *--yesterday*, *--week*, *--month*, *--year*
	Restrict output to the named time range.

*--from* _time_, *--to* _time_
	Restrict output to a custom range. Format: _HH:MM_ or _YYYY-MM-DD HH:MM_.

## Output format

*--json*
	Emit output as JSON.

*--csv*
	Emit output as CSV (log and report only).

# ENVIRONMENT

*WOTIN_DB*
	Path to the SQLite database file. Default: _~/.wotin/timetracking.db_.

*NO_COLOR*
	Disable colored terminal output when set to any non-empty value.

# FILES

_~/.wotin/timetracking.db_
	Default SQLite database.

_~/.config/wotin/config_
	Optional configuration file. Supports *db_path* and *no_color* keys.

# SEE ALSO

*watson*(1)
