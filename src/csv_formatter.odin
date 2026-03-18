package main

import "core:fmt"
import "core:strings"

csv_escape :: proc(s: string) -> string {
	if strings.contains(s, ",") || strings.contains(s, "\"") || strings.contains(s, "\n") {
		escaped, _ := strings.replace_all(s, "\"", "\"\"", context.temp_allocator)
		return fmt.tprintf("\"%s\"", escaped)
	}
	return s
}

format_entries_csv :: proc(entries: []TimeEntryInfo) {
	fmt.println("frame_id,project,tags,start,stop")
	for e in entries {
		fmt.printf(
			"%s,%s,%s,%s,%s\n",
			csv_escape(e.frame_id),
			csv_escape(e.project),
			csv_escape(e.tags),
			csv_escape(e.start_time),
			csv_escape(e.stop_time),
		)
	}
}

format_report_csv :: proc(reports: []ProjectReport) {
	fmt.println("project,tag,seconds")
	for r in reports {
		if r.total_seconds == 0 do continue
		fmt.printf("%s,,%d\n", csv_escape(r.project), r.total_seconds)
		for tag, seconds in r.tag_times {
			fmt.printf("%s,%s,%d\n", csv_escape(r.project), csv_escape(tag), seconds)
		}
	}
}
