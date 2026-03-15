package main

import "core:fmt"
import "core:strings"

// Simple JSON formatting (minimal implementation)

json_escape :: proc(s: string) -> string {
	// Escape quotes and backslashes
	result := strings.builder_make(context.temp_allocator)
	for c in s {
		switch c {
		case '"':
			strings.write_string(&result, "\\\"")
		case '\\':
			strings.write_string(&result, "\\\\")
		case '\n':
			strings.write_string(&result, "\\n")
		case '\r':
			strings.write_string(&result, "\\r")
		case '\t':
			strings.write_string(&result, "\\t")
		case:
			strings.write_rune(&result, c)
		}
	}
	return strings.to_string(result)
}

format_time_entry_json :: proc(entry: TimeEntryInfo, frame_id: string = "") -> string {
	builder := strings.builder_make(context.temp_allocator)
	strings.write_string(&builder, "{")

	if len(frame_id) > 0 {
		fmt.sbprintf(&builder, "\"frame_id\":\"%s\",", json_escape(frame_id))
	}

	fmt.sbprintf(&builder, "\"project\":\"%s\",", json_escape(entry.project))
	fmt.sbprintf(&builder, "\"start_time\":\"%s\",", json_escape(entry.start_time))

	if len(entry.stop_time) > 0 {
		fmt.sbprintf(&builder, "\"stop_time\":\"%s\",", json_escape(entry.stop_time))
	} else {
		strings.write_string(&builder, "\"stop_time\":null,")
	}

	strings.write_string(&builder, "\"tags\":[")
	if len(entry.tags) > 0 {
		tag_parts := strings.split(entry.tags, ",", context.temp_allocator)
		for tag, i in tag_parts {
			if i > 0 do strings.write_string(&builder, ",")
			fmt.sbprintf(&builder, "\"%s\"", json_escape(strings.trim_space(tag)))
		}
	}
	strings.write_string(&builder, "]}")

	return strings.to_string(builder)
}

format_entries_json :: proc(entries: []TimeEntryInfo) -> string {
	builder := strings.builder_make(context.temp_allocator)
	strings.write_string(&builder, "[")

	for entry, i in entries {
		if i > 0 do strings.write_string(&builder, ",")
		strings.write_string(&builder, format_time_entry_json(entry))
	}

	strings.write_string(&builder, "]")
	return strings.to_string(builder)
}
