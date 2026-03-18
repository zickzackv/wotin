package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:terminal"
import "core:terminal/ansi"

main :: proc() {
	args := os.args[1:]

	// Strip global --db <path> flag before subcommand dispatch
	if len(args) >= 2 && args[0] == "--db" {
		os.set_env("WOTIN_DB", args[1])
		args = args[2:]
	}

	if !init_database() {
		fmt.eprintln("Failed to initialize database")
		os.exit(1)
	}
	defer close_database()

	if len(args) < 1 {
		print_help()
		return
	}

	switch args[0] {
	case "status", "current":
		entry, frame_id, ok := get_current_entry()
		if !ok {
			fmt.println("No timer is currently running")
			os.exit(1)
		}
		defer {
			delete(entry.project)
			delete(entry.start_time)
			delete(entry.stop_time)
			delete(entry.tags)
			delete(frame_id)
		}
		fmt.printf("Project %s", sgr(ansi.FG_GREEN, entry.project))
		if len(entry.tags) > 0 {
			fmt.printf(" [%s]", sgr(ansi.FG_CYAN, entry.tags))
		}
		fmt.printf(" started at %s (frame: %s)\n", entry.start_time, sgr(ansi.FAINT, frame_id))

	case "cancel":
		if cancel_current_entry() {
			fmt.println("Cancelled current activity")
		} else {
			fmt.eprintln("Error: No timer is currently running")
			os.exit(1)
		}

	case "restart":
		// Auto-stop current if running
		current, cur_frame, is_running := get_current_entry()
		if is_running {
			defer {
				delete(current.project)
				delete(current.start_time)
				delete(current.stop_time)
				delete(current.tags)
				delete(cur_frame)
			}
			if stop_tracking() {
				fmt.printf("Stopped: %s (frame: %s)\n", current.project, cur_frame)
			}
		}

		last, _, has_last := get_last_entry()
		if !has_last {
			fmt.eprintln("Error: No previous activity to restart")
			os.exit(1)
		}
		defer {
			delete(last.project)
			delete(last.start_time)
			delete(last.stop_time)
			delete(last.tags)
		}

		// Rebuild tags slice from comma-separated string
		tags: [dynamic]string
		defer delete(tags)
		if len(last.tags) > 0 {
			for t in strings.split(last.tags, ",", context.temp_allocator) {
				trimmed := strings.trim_space(t)
				if len(trimmed) > 0 do append(&tags, trimmed)
			}
		}

		if start_tracking(last.project, tags[:]) {
			fmt.printf("Restarted: %s", last.project)
			if len(last.tags) > 0 {
				fmt.printf(" [%s]", last.tags)
			}
			fmt.println()
		} else {
			os.exit(1)
		}

	case "remove":
		if len(args) < 2 {
			fmt.eprintln("Error: frame ID required")
			fmt.eprintln("Usage: wotin remove <frame_id>")
			os.exit(1)
		}
		frame_id := args[1]
		if remove_entry_by_frame_id(frame_id) {
			fmt.printf("Removed frame %s\n", frame_id)
		} else {
			fmt.fprintf(os.stderr, "Error: frame '%s' not found\n", frame_id)
			os.exit(1)
		}

	case "change":
		// wotin change <frame_id> [--project <name>] [+tag...] [--tags t1,t2]
		if len(args) < 2 {
			fmt.eprintln("Error: frame ID required")
			fmt.eprintln("Usage: wotin change <frame_id> [--project <name>] [+tag...]")
			os.exit(1)
		}
		frame_id := args[1]
		parsed := parse_watson_args(args[2:])
		defer free_parsed_args(&parsed)

		new_project := ""
		if p, ok := parsed.flags["project"]; ok {
			new_project = p
		}
		has_tags := len(parsed.tags) > 0
		if _, ok := parsed.flags["tags"]; ok {
			has_tags = true
		}

		if len(new_project) == 0 && !has_tags {
			fmt.eprintln("Error: specify --project and/or +tags to change")
			os.exit(1)
		}

		if change_entry(frame_id, new_project, parsed.tags[:], has_tags) {
			fmt.printf("Updated frame %s\n", frame_id)
		} else {
			fmt.fprintf(os.stderr, "Error: frame '%s' not found\n", frame_id)
			os.exit(1)
		}

	case "aggregate":
		parsed := parse_watson_args(args[1:])
		defer free_parsed_args(&parsed)

		from_sql, to_sql := resolve_time_range_sql(parsed.flags)
		rows := get_aggregate_data(from_sql, to_sql)
		defer {
			for r in rows {
				delete(r.date)
				delete(r.project)
			}
			delete(rows)
		}

		if _, has_json := parsed.flags["json"]; has_json {
			fmt.print("[")
			for r, i in rows {
				if i > 0 do fmt.print(",")
				fmt.printf(
					"{\"date\":\"%s\",\"project\":\"%s\",\"seconds\":%d}",
					r.date,
					r.project,
					r.seconds,
				)
			}
			fmt.println("]")
		} else {
			current_date := ""
			day_total: i64 = 0
			for r in rows {
				if r.date != current_date {
					if current_date != "" {
						fmt.printf("  %-44s %s\n", "Total", format_duration(day_total))
						fmt.println()
					}
					fmt.printf("%s\n", r.date)
					current_date = r.date
					day_total = 0
				}
				fmt.printf("  %-44s %s\n", r.project, format_duration(r.seconds))
				day_total += r.seconds
			}
			if current_date != "" {
				fmt.printf("  %-44s %s\n", "Total", format_duration(day_total))
			}
		}

	case "projects":
		projects := list_projects()
		defer {
			for p in projects {
				delete(p.name)
				delete(p.total_time)
			}
			delete(projects)
		}
		format_projects(projects)

	case "tags":
		tags := list_tags()
		defer {
			for t in tags {
				delete(t.name)
			}
			delete(tags)
		}
		format_tags(tags)

	case "rename":
		// wotin rename project <old> <new>
		// wotin rename tag <old> <new>
		if len(args) < 4 {
			fmt.eprintln("Usage: wotin rename project|tag <old-name> <new-name>")
			os.exit(1)
		}
		kind, old_name, new_name := args[1], args[2], args[3]
		switch kind {
		case "project":
			if rename_project(old_name, new_name) {
				fmt.printf("Renamed project '%s' -> '%s'\n", old_name, new_name)
			} else {
				fmt.fprintf(os.stderr, "Error: project '%s' not found\n", old_name)
				os.exit(1)
			}
		case "tag":
			if rename_tag(old_name, new_name) {
				fmt.printf("Renamed tag '%s' -> '%s'\n", old_name, new_name)
			} else {
				fmt.fprintf(os.stderr, "Error: tag '%s' not found\n", old_name)
				os.exit(1)
			}
		case:
			fmt.fprintf(os.stderr, "Error: unknown type '%s', use 'project' or 'tag'\n", kind)
			os.exit(1)
		}

	case "edit":
		if len(args) < 2 {
			fmt.eprintln("Usage: wotin edit <frame_id>")
			os.exit(1)
		}
		if !edit_frame_in_editor(args[1]) {
			os.exit(1)
		}
		fmt.printf("Updated frame %s\n", args[1])

	case "import":
		if len(args) < 2 {
			fmt.eprintln("Usage: wotin import <path-to-watson-frames>")
			fmt.eprintln("Default Watson path: ~/.config/watson/frames")
			os.exit(1)
		}
		path := args[1]
		imported, skipped, ok := import_watson_frames(path)
		if !ok {
			os.exit(1)
		}
		fmt.printf("Imported %d entries", imported)
		if skipped > 0 do fmt.printf(", skipped %d", skipped)
		fmt.println()

	case "version", "--version":
		fmt.printf("wotin %s\n", WOTIN_VERSION)

	case "help", "--help", "-h":
		print_help()

	case "start":
		if len(args) < 2 {
			fmt.println("Error: project name required")
			fmt.println("Usage: timer start <project> [+tag1 +tag2...] [--at HH:MM]")
			os.exit(1)
		}

		// Parse Watson-style arguments
		parsed := parse_watson_args(args[1:])
		defer free_parsed_args(&parsed)

		if len(parsed.positional) == 0 {
			fmt.println("Error: project name required")
			os.exit(1)
		}

		project := parsed.positional[0]

		// Resolve optional --at time
		at_time := ""
		if at_str, has_at := parsed.flags["at"]; has_at {
			parsed_at, at_ok := parse_datetime(at_str)
			if !at_ok {
				fmt.eprintln("Error: invalid --at time format, use HH:MM or YYYY-MM-DD HH:MM")
				os.exit(1)
			}
			at_time = parsed_at
		}

		// Auto-stop current activity if running
		current, frame_id, is_running := get_current_entry()
		if is_running {
			defer {
				delete(current.project)
				delete(current.start_time)
				delete(current.stop_time)
				delete(current.tags)
				delete(frame_id)
			}

			if stop_tracking() {
				fmt.printf(
					"Stopped: %s [%s] (frame: %s)\n",
					current.project,
					current.tags,
					frame_id,
				)
			}
		}

		if start_tracking(project, parsed.tags[:], at_time) {
			fmt.printf("Started: %s", project)
			if len(parsed.tags) > 0 {
				fmt.printf(" [")
				for tag, i in parsed.tags {
					if i > 0 do fmt.printf(", ")
					fmt.printf("%s", tag)
				}
				fmt.printf("]")
			}
			fmt.println()
		} else {
			os.exit(1)
		}

	case "stop":
		// Get current entry before stopping
		current, frame_id, is_running := get_current_entry()
		if !is_running {
			fmt.eprintln("Error: No timer is currently running")
			os.exit(1)
		}
		defer {
			delete(current.project)
			delete(current.start_time)
			delete(current.stop_time)
			delete(current.tags)
			delete(frame_id)
		}

		if stop_tracking() {
			fmt.printf("Stopped: %s", current.project)
			if len(current.tags) > 0 {
				fmt.printf(" [%s]", current.tags)
			}
			fmt.printf(" started at %s (frame: %s)\n", current.start_time, frame_id)
		} else {
			os.exit(1)
		}

	case "frames":
		frames := list_frame_ids()
		defer {
			for f in frames do delete(f)
			delete(frames)
		}

		for frame_id in frames {
			fmt.println(frame_id)
		}

	case "log":
		parsed := parse_watson_args(args[1:])
		defer free_parsed_args(&parsed)

		from_sql, to_sql := resolve_time_range_sql(parsed.flags)
		entries := list_time_entries(from_sql, to_sql)
		defer {
			for e in entries {
				delete(e.frame_id)
				delete(e.project)
				delete(e.start_time)
				delete(e.stop_time)
				delete(e.tags)
			}
			delete(entries)
		}

		if _, has_json := parsed.flags["json"]; has_json {
			fmt.println(format_entries_json(entries[:]))
		} else if _, has_csv := parsed.flags["csv"]; has_csv {
			format_entries_csv(entries[:])
		} else {
			current_date := ""
			for entry in entries {
				date := entry.start_time[:10] if len(entry.start_time) >= 10 else ""
				if date != current_date {
					if current_date != "" do fmt.println()
					fmt.printf("%s\n", sgr(ansi.BOLD, date))
					current_date = date
				}
				start_time :=
					entry.start_time[11:16] if len(entry.start_time) >= 16 else entry.start_time
				stop_time := entry.stop_time[11:16] if len(entry.stop_time) >= 16 else "running"
				fmt.printf("  %s to %-8s  %s", start_time, stop_time, sgr(ansi.FG_GREEN, entry.project))
				if len(entry.tags) > 0 {
					fmt.printf(" [%s]", sgr(ansi.FG_CYAN, entry.tags))
				}
				if len(entry.frame_id) > 0 {
					fmt.printf("  (%s)", sgr(ansi.FAINT, entry.frame_id))
				}
				fmt.println()
			}
		}

	case "report":
		parsed := parse_watson_args(args[1:])
		defer free_parsed_args(&parsed)

		from_sql, to_sql := resolve_time_range_sql(parsed.flags)
		reports := get_report_data(from_sql, to_sql)
		defer {
			for r in reports {
				delete(r.project)
				delete(r.tag_times)
			}
			delete(reports)
		}

		if _, has_json := parsed.flags["json"]; has_json {
			fmt.print("{\"projects\":[")
			for report, i in reports {
				if i > 0 do fmt.print(",")
				fmt.printf(
					"{\"name\":\"%s\",\"seconds\":%d}",
					report.project,
					report.total_seconds,
				)
			}
			fmt.println("]}")
		} else if _, has_csv := parsed.flags["csv"]; has_csv {
			format_report_csv(reports[:])
		} else {
			total_seconds: i64 = 0
			for report in reports {
				if report.total_seconds == 0 do continue
				fmt.printf("%s", sgr(ansi.FG_GREEN, report.project))
				padding := 50 - len(report.project)
				for i := 0; i < padding; i += 1 do fmt.print(".")
				fmt.printf(" %s\n", format_duration(report.total_seconds))
				for tag, seconds in report.tag_times {
					fmt.printf("    [%s]", sgr(ansi.FG_CYAN, tag))
					tag_padding := 42 - len(tag)
					for i := 0; i < tag_padding; i += 1 do fmt.print(".")
					fmt.printf(" %s\n", format_duration(seconds))
				}
				total_seconds += report.total_seconds
			}
			fmt.println()
			fmt.printf("%s", sgr(ansi.BOLD, "Total"))
			for i := 0; i < 45; i += 1 do fmt.print(".")
			fmt.printf(" %s\n", format_duration(total_seconds))
		}

	case "list":
		if len(args) < 2 {
			fmt.println("Error: list type required")
			fmt.println("Usage: timer list <projects|entries|tags>")
			os.exit(1)
		}

		switch args[1] {
		case "projects":
			projects := list_projects()
			defer delete(projects)
			format_projects(projects)
		case "entries":
			entries := list_time_entries()
			defer {
				for e in entries {
					delete(e.frame_id)
					delete(e.project)
					delete(e.start_time)
					delete(e.stop_time)
					delete(e.tags)
				}
				delete(entries)
			}
			format_time_entries(entries)
		case "tags":
			tags := list_tags()
			defer delete(tags)
			format_tags(tags)
		case:
			fmt.printf("Unknown list type: '%s'\n", args[1])
			fmt.println("Usage: timer list <projects|entries|tags>")
			os.exit(1)
		}

	case "add":
		if len(args) < 2 {
			fmt.println("Error: project name required")
			fmt.println(
				"Usage: timer add <project> --from <time> --to <time> [--tags tag1,tag2,...]",
			)
			os.exit(1)
		}

		project := args[1]
		from_time := ""
		to_time := ""
		tags: [dynamic]string
		defer delete(tags)

		// Parse arguments
		i := 2
		for i < len(args) {
			switch args[i] {
			case "--from":
				if i + 1 < len(args) {
					from_time = args[i + 1]
					i += 2
				} else {
					fmt.println("Error: --from requires a value")
					os.exit(1)
				}
			case "--to":
				if i + 1 < len(args) {
					to_time = args[i + 1]
					i += 2
				} else {
					fmt.println("Error: --to requires a value")
					os.exit(1)
				}
			case "--tags":
				if i + 1 < len(args) {
					tag_str := args[i + 1]
					tag_parts := strings.split(tag_str, ",", context.temp_allocator)
					for tag in tag_parts {
						trimmed := strings.trim_space(tag)
						if len(trimmed) > 0 {
							append(&tags, trimmed)
						}
					}
					i += 2
				} else {
					fmt.println("Error: --tags requires a value")
					os.exit(1)
				}
			case:
				fmt.printf("Unknown option: '%s'\n", args[i])
				os.exit(1)
			}
		}

		if len(from_time) == 0 || len(to_time) == 0 {
			fmt.println("Error: --from and --to are required")
			fmt.println(
				"Usage: timer add <project> --from <time> --to <time> [--tags tag1,tag2,...]",
			)
			os.exit(1)
		}

		// Parse times
		from_parsed, from_ok := parse_datetime(from_time)
		to_parsed, to_ok := parse_datetime(to_time)

		if !from_ok || !to_ok {
			fmt.println(
				"Error: Invalid time format. Use 'YYYY-MM-DD HH:MM', 'YYYY-MM-DDTHH:MM', or 'HH:MM'",
			)
			os.exit(1)
		}

		// Validate from < to
		if from_parsed >= to_parsed {
			fmt.println("Error: --from time must be before --to time")
			os.exit(1)
		}

		if add_time_entry(project, from_parsed, to_parsed, tags[:]) {
			fmt.printf("Time entry added for project: %s\n", project)
			fmt.printf("From: %s\n", from_parsed)
			fmt.printf("To: %s\n", to_parsed)
			if len(tags) > 0 {
				fmt.printf("Tags: %v\n", tags)
			}
		} else {
			os.exit(1)
		}

	case "completion":
		if len(args) < 2 {
			fmt.eprintln("Usage: wotin completion bash|zsh|fish")
			os.exit(1)
		}
		print_completion(args[1])

	case:
		fmt.fprintf(os.stderr, "Unknown command: '%s'\n", args[0])
		fmt.eprintln("Run 'wotin help' for usage.")
		os.exit(1)
	}
}

print_help :: proc() {
	fmt.println(
		`wotin - Work Time Tracker

Usage: wotin [--db <path>] <command> [args]

Global options:
  --db <path>                                Use a specific database file
                                             (overrides WOTIN_DB env var)

Tracking:
  start <project> [+tag...] [--at HH:MM]   Start tracking (auto-stops current)
  stop                                       Stop current activity
  cancel                                     Delete current activity without saving
  restart                                    Restart the last stopped activity
  status / current                           Show currently running activity

Viewing:
  log [--json] [--today|--week|--month|--year|--from T --to T]
  report [--json] [--today|--week|--month|--year|--from T --to T]
  aggregate [--json] [--today|--week|--month|--year|--from T --to T]
  frames                                     List all frame IDs
  projects                                   List all projects with total time
  tags                                       List all tags with usage count

Management:
  remove <frame_id>                          Delete an entry by frame ID
  change <frame_id> [--project <n>]          Change project and/or tags
    [+tag...] [--tags tag1,tag2]
  edit <frame_id> [--from <t>] [--to <t>]   Edit start/stop times
  rename project|tag <old> <new>             Rename a project or tag everywhere
  add <project> --from <t> --to <t>          Manually add a past activity
    [+tag...] [--tags tag1,tag2]
  import <path>                              Import from Watson frames file
                                             (default: ~/.config/watson/frames)

Time formats: HH:MM  or  YYYY-MM-DD HH:MM

Environment:
  WOTIN_DB                                   Path to the SQLite database file
                                             Default: ~/.wotin/timetracking.db

Examples:
  wotin start myproject +backend +api
  wotin log --today
  wotin report --week
  wotin aggregate --month
  wotin edit abc1234 --from 09:00 --to 10:30
  wotin rename project old-name new-name
  wotin rename tag backend be
  WOTIN_DB=~/work.db wotin log
  wotin --db ~/work.db log --today
`,
	)
}
