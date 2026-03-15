package main

import "core:fmt"
import "core:strings"

format_projects :: proc(projects: [dynamic]ProjectInfo) {
	if len(projects) == 0 {
		fmt.println("No projects found")
		return
	}
	
	// Calculate column widths
	max_name := 7 // "Project"
	for p in projects {
		if len(p.name) > max_name {
			max_name = len(p.name)
		}
	}
	
	// Print header
	fmt.printf("%-*s  %s\n", max_name, "Project", "Time")
	fmt.println(strings.repeat("-", max_name + 2 + 5))
	
	// Print rows
	for p in projects {
		fmt.printf("%-*s  %s\n", max_name, p.name, p.total_time)
	}
}

format_time_entries :: proc(entries: [dynamic]TimeEntryInfo) {
	if len(entries) == 0 {
		fmt.println("No time entries found")
		return
	}
	
	// Calculate column widths
	max_project := 7 // "Project"
	max_start := 19 // "2026-02-26 17:14"
	max_stop := 5 // "Stop"
	
	for e in entries {
		if len(e.project) > max_project {
			max_project = len(e.project)
		}
		if len(e.start_time) > max_start {
			max_start = len(e.start_time)
		}
		if len(e.stop_time) > max_stop {
			max_stop = len(e.stop_time)
		}
	}
	
	// Print header
	fmt.printf("%-*s  %-*s  %-*s  %s\n", max_project, "Project", max_start, "Start", max_stop, "Stop", "Tags")
	fmt.println(strings.repeat("-", max_project + 2 + max_start + 2 + max_stop + 2 + 20))
	
	// Print rows
	for e in entries {
		stop := e.stop_time
		if len(stop) == 0 {
			stop = "running"
		}
		fmt.printf("%-*s  %-*s  %-*s  %s\n", max_project, e.project, max_start, e.start_time, max_stop, stop, e.tags)
	}
}

format_tags :: proc(tags: [dynamic]TagInfo) {
	if len(tags) == 0 {
		fmt.println("No tags found")
		return
	}
	
	// Calculate column widths
	max_name := 3 // "Tag"
	for t in tags {
		if len(t.name) > max_name {
			max_name = len(t.name)
		}
	}
	
	// Print header
	fmt.printf("%-*s  %s\n", max_name, "Tag", "Count")
	fmt.println(strings.repeat("-", max_name + 2 + 5))
	
	// Print rows
	for t in tags {
		fmt.printf("%-*s  %d\n", max_name, t.name, t.count)
	}
}
