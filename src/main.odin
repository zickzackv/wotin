package main

import "core:fmt"
import "core:os"
import "core:strings"

main :: proc() {
	if !init_database() {
		fmt.eprintln("Failed to initialize database")
		os.exit(1)
	}
	defer close_database()

	args := os.args
	if len(args) < 2 {
		fmt.println("Usage: timer <start|stop>")
		fmt.println("  start <project> [--tags tag1,tag2,...]")
		fmt.println("  stop")
		return
	}

	switch args[1] {
	case "start":
		if len(args) < 3 {
			fmt.println("Error: project name required")
			fmt.println("Usage: timer start <project> [--tags tag1,tag2,...]")
			os.exit(1)
		}
		
		project := args[2]
		tags: [dynamic]string
		defer delete(tags)
		
		// Parse tags if provided
		if len(args) >= 5 && args[3] == "--tags" {
			tag_str := args[4]
			tag_parts := strings.split(tag_str, ",", context.temp_allocator)
			for tag in tag_parts {
				trimmed := strings.trim_space(tag)
				if len(trimmed) > 0 {
					append(&tags, trimmed)
				}
			}
		}
		
		if start_tracking(project, tags[:]) {
			fmt.printf("Timer started for project: %s\n", project)
			if len(tags) > 0 {
				fmt.printf("Tags: %v\n", tags)
			}
		} else {
			os.exit(1)
		}
		
	case "stop":
		if stop_tracking() {
			fmt.println("Timer stopped")
		} else {
			os.exit(1)
		}
		
	case:
		fmt.printf("Unknown command: '%s'\n", args[1])
		fmt.println("Usage: timer <start|stop>")
		os.exit(1)
	}
}

