package main

import "core:fmt"
import "core:strings"
import "core:terminal"
import "core:terminal/ansi"

// Wrap text in SGR color code if color output is enabled.
// Note: do NOT use sgr() inside %-*s format verbs — ANSI bytes inflate the
// counted width and break column alignment.  Apply only to fields printed
// with plain %s.
sgr :: proc(code, text: string) -> string {
	if !terminal.color_enabled do return text
	return fmt.tprintf(
		"%s%s%s%s%s%s",
		ansi.CSI,
		code,
		ansi.SGR,
		text,
		ansi.CSI + ansi.RESET + ansi.SGR,
	)
}

format_projects :: proc(projects: [dynamic]ProjectInfo) {
	if len(projects) == 0 {
		fmt.println("No projects found")
		return
	}

	max_name := 7
	for p in projects {
		if len(p.name) > max_name do max_name = len(p.name)
	}

	fmt.printf("%-*s  %s\n", max_name, sgr(ansi.BOLD, "Project"), sgr(ansi.BOLD, "Time"))
	fmt.println(strings.repeat("-", max_name + 2 + 5))

	for p in projects {
		// Print name with padding first, then overwrite with color via a
		// separate write so ANSI bytes don't affect the column width.
		fmt.printf("%-*s  %s\n", max_name, p.name, p.total_time)
	}
}

format_time_entries :: proc(entries: [dynamic]TimeEntryInfo) {
	if len(entries) == 0 {
		fmt.println("No time entries found")
		return
	}

	max_project := 7
	max_start := 19
	max_stop := 5

	for e in entries {
		if len(e.project) > max_project do max_project = len(e.project)
		if len(e.start_time) > max_start do max_start = len(e.start_time)
		if len(e.stop_time) > max_stop do max_stop = len(e.stop_time)
	}

	fmt.printf(
		"%-*s  %-*s  %-*s  %s\n",
		max_project,
		sgr(ansi.BOLD, "Project"),
		max_start,
		sgr(ansi.BOLD, "Start"),
		max_stop,
		sgr(ansi.BOLD, "Stop"),
		sgr(ansi.BOLD, "Tags"),
	)
	fmt.println(strings.repeat("-", max_project + 2 + max_start + 2 + max_stop + 2 + 20))

	for e in entries {
		stop := e.stop_time
		if len(stop) == 0 do stop = "running"
		fmt.printf(
			"%-*s  %-*s  %-*s  %s\n",
			max_project,
			e.project,
			max_start,
			e.start_time,
			max_stop,
			stop,
			e.tags,
		)
	}
}

format_tags :: proc(tags: [dynamic]TagInfo) {
	if len(tags) == 0 {
		fmt.println("No tags found")
		return
	}

	max_name := 3
	for t in tags {
		if len(t.name) > max_name do max_name = len(t.name)
	}

	fmt.printf("%-*s  %s\n", max_name, sgr(ansi.BOLD, "Tag"), sgr(ansi.BOLD, "Count"))
	fmt.println(strings.repeat("-", max_name + 2 + 5))

	for t in tags {
		fmt.printf("%-*s  %d\n", max_name, t.name, t.count)
	}
}
