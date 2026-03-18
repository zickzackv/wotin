package main

import "core:encoding/json"
import "core:strings"

// JSON struct for log output
TimeEntryJson :: struct {
	frame_id:   string `json:"frame_id,omitempty"`,
	project:    string `json:"project"`,
	start_time: string `json:"start_time"`,
	stop_time:  string `json:"stop_time,omitempty"`,
	tags:       []string `json:"tags"`,
}

format_time_entry_json :: proc(entry: TimeEntryInfo, frame_id: string = "") -> string {
	tags: []string
	if len(entry.tags) > 0 {
		parts := strings.split(entry.tags, ",", context.temp_allocator)
		for &p in parts do p = strings.trim_space(p)
		tags = parts
	} else {
		tags = {}
	}
	j := TimeEntryJson {
		frame_id   = frame_id,
		project    = entry.project,
		start_time = entry.start_time,
		stop_time  = entry.stop_time,
		tags       = tags,
	}
	data, err := json.marshal(j, allocator = context.temp_allocator)
	if err != nil do return "{}"
	return string(data)
}

format_entries_json :: proc(entries: []TimeEntryInfo) -> string {
	b := strings.builder_make(context.temp_allocator)
	strings.write_byte(&b, '[')
	for entry, i in entries {
		if i > 0 do strings.write_byte(&b, ',')
		strings.write_string(&b, format_time_entry_json(entry))
	}
	strings.write_byte(&b, ']')
	return strings.to_string(b)
}

format_report_json :: proc(reports: []ProjectReport) -> string {
	b := strings.builder_make(context.temp_allocator)
	strings.write_string(&b, `{"projects":[`)
	for r, i in reports {
		if i > 0 do strings.write_byte(&b, ',')
		strings.write_string(&b, `{"name":`)
		data, _ := json.marshal(r.project, allocator = context.temp_allocator)
		strings.write_string(&b, string(data))
		strings.write_string(&b, `,"seconds":`)
		strings.write_i64(&b, r.total_seconds)
		strings.write_byte(&b, '}')
	}
	strings.write_string(&b, "]}")
	return strings.to_string(b)
}
