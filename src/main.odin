package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"

main :: proc() {
	if !init_database() {
		fmt.eprintln("Failed to initialize database")
		os.exit(1)
	}
	defer close_database()

	args := os.args
	if len(args) < 2 {
		fmt.println("Usage: timer <start|stop|list|add>")
		fmt.println("  start <project> [--tags tag1,tag2,...]")
		fmt.println("  stop")
		fmt.println("  list <projects|entries|tags>")
		fmt.println("  add <project> --from <time> --to <time> [--tags tag1,tag2,...]")
		return
	}

	switch args[1] {
	case "test-parse":
		// Test the argument parser
		if len(args) < 3 {
			fmt.println("Usage: timer test-parse <args...>")
			return
		}
		parsed := parse_watson_args(args[2:])
		defer free_parsed_args(&parsed)
		
		fmt.println("Positional:", parsed.positional)
		fmt.println("Tags:", parsed.tags)
		fmt.println("Flags:", parsed.flags)
		
	case "test-time":
		// Test time shortcuts
		if len(args) < 3 {
			fmt.println("Usage: timer test-time --today|--yesterday|--week|--month|--year")
			return
		}
		parsed := parse_watson_args(args[2:])
		defer free_parsed_args(&parsed)
		
		range, ok := resolve_time_range(parsed.flags)
		if ok {
			fmt.println("Time range:", format_time_range(range))
		} else {
			fmt.println("Failed to resolve time range")
		}
		
	case "status":
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
		
		// Calculate elapsed time
		now := time.now()
		// Parse start time (simplified - assumes format YYYY-MM-DD HH:MM:SS)
		fmt.printf("Project %s", entry.project)
		if len(entry.tags) > 0 {
			fmt.printf(" [%s]", entry.tags)
		}
		fmt.printf(" started at %s (frame: %s)\n", entry.start_time, frame_id)
		
	case "cancel":
		if cancel_current_entry() {
			fmt.println("Cancelled current activity")
		} else {
			fmt.eprintln("Error: No timer is currently running")
			os.exit(1)
		}
		
	case "start":
		if len(args) < 3 {
			fmt.println("Error: project name required")
			fmt.println("Usage: timer start <project> [+tag1 +tag2...] [--at HH:MM]")
			os.exit(1)
		}
		
		// Parse Watson-style arguments
		parsed := parse_watson_args(args[2:])
		defer free_parsed_args(&parsed)
		
		if len(parsed.positional) == 0 {
			fmt.println("Error: project name required")
			os.exit(1)
		}
		
		project := parsed.positional[0]
		
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
				fmt.printf("Stopped: %s [%s] (frame: %s)\n", current.project, current.tags, frame_id)
			}
		}
		
		if start_tracking(project, parsed.tags[:]) {
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
		// Parse arguments
		parsed := parse_watson_args(args[2:])
		defer free_parsed_args(&parsed)
		
		entries := list_time_entries()
		defer {
			for e in entries {
				delete(e.project)
				delete(e.start_time)
				delete(e.stop_time)
				delete(e.tags)
			}
			delete(entries)
		}
		
		// Check for JSON output
		if _, has_json := parsed.flags["json"]; has_json {
			fmt.println(format_entries_json(entries[:]))
		} else {
			// Group by date
			current_date := ""
			for entry in entries {
				// Extract date from start_time (YYYY-MM-DD HH:MM:SS)
				date := entry.start_time[:10] if len(entry.start_time) >= 10 else ""
				
				if date != current_date {
					if current_date != "" do fmt.println()
					fmt.printf("%s\n", date)
					current_date = date
				}
				
				// Format: HH:MM to HH:MM  Duration  Project [tags]
				start_time := entry.start_time[11:16] if len(entry.start_time) >= 16 else entry.start_time
				stop_time := entry.stop_time[11:16] if len(entry.stop_time) >= 16 else "running"
				
				fmt.printf("  %s to %-8s  %s", start_time, stop_time, entry.project)
				if len(entry.tags) > 0 {
					fmt.printf(" [%s]", entry.tags)
				}
				fmt.println()
			}
		}
		
	case "report":
		// Parse arguments
		parsed := parse_watson_args(args[2:])
		defer free_parsed_args(&parsed)
		
		reports := get_report_data()
		defer {
			for r in reports {
				delete(r.project)
				delete(r.tag_times)
			}
			delete(reports)
		}
		
		// Check for JSON output
		if _, has_json := parsed.flags["json"]; has_json {
			// Simple JSON output
			fmt.print("{\"projects\":[")
			for report, i in reports {
				if i > 0 do fmt.print(",")
				fmt.printf("{\"name\":\"%s\",\"seconds\":%d}", report.project, report.total_seconds)
			}
			fmt.println("]}")
		} else {
			total_seconds: i64 = 0
			
			for report in reports {
				if report.total_seconds == 0 do continue
				
				fmt.printf("%s", report.project)
				// Pad to 50 chars
				padding := 50 - len(report.project)
				for i := 0; i < padding; i += 1 do fmt.print(".")
				fmt.printf(" %s\n", format_duration(report.total_seconds))
				
				// Show tag breakdown
				for tag, seconds in report.tag_times {
					fmt.printf("    [%s]", tag)
					tag_padding := 42 - len(tag)
					for i := 0; i < tag_padding; i += 1 do fmt.print(".")
					fmt.printf(" %s\n", format_duration(seconds))
				}
				
				total_seconds += report.total_seconds
			}
			
			fmt.println()
			fmt.printf("Total")
			for i := 0; i < 45; i += 1 do fmt.print(".")
			fmt.printf(" %s\n", format_duration(total_seconds))
		}
		
	case "list":
		if len(args) < 3 {
			fmt.println("Error: list type required")
			fmt.println("Usage: timer list <projects|entries|tags>")
			os.exit(1)
		}
		
		switch args[2] {
		case "projects":
			projects := list_projects()
			defer delete(projects)
			format_projects(projects)
		case "entries":
			entries := list_time_entries()
			defer delete(entries)
			format_time_entries(entries)
		case "tags":
			tags := list_tags()
			defer delete(tags)
			format_tags(tags)
		case:
			fmt.printf("Unknown list type: '%s'\n", args[2])
			fmt.println("Usage: timer list <projects|entries|tags>")
			os.exit(1)
		}
		
	case "add":
		if len(args) < 3 {
			fmt.println("Error: project name required")
			fmt.println("Usage: timer add <project> --from <time> --to <time> [--tags tag1,tag2,...]")
			os.exit(1)
		}
		
		project := args[2]
		from_time := ""
		to_time := ""
		tags: [dynamic]string
		defer delete(tags)
		
		// Parse arguments
		i := 3
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
			fmt.println("Usage: timer add <project> --from <time> --to <time> [--tags tag1,tag2,...]")
			os.exit(1)
		}
		
		// Parse times
		from_parsed, from_ok := parse_datetime(from_time)
		to_parsed, to_ok := parse_datetime(to_time)
		
		if !from_ok || !to_ok {
			fmt.println("Error: Invalid time format. Use 'YYYY-MM-DD HH:MM', 'YYYY-MM-DDTHH:MM', or 'HH:MM'")
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
		
	case:
		fmt.printf("Unknown command: '%s'\n", args[1])
		fmt.println("Usage: timer <start|stop|list|add>")
		os.exit(1)
	}
}

