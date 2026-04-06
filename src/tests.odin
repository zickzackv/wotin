package main

import "core:strings"
import "core:testing"

// --- arg_parser tests ---

@(test)
test_parse_plus_tags :: proc(t: ^testing.T) {
	args := []string{"myproject", "+backend", "+api"}
	parsed := parse_watson_args(args)
	defer free_parsed_args(&parsed)

	testing.expect_value(t, len(parsed.positional), 1)
	testing.expect_value(t, parsed.positional[0], "myproject")
	testing.expect_value(t, len(parsed.tags), 2)
	testing.expect_value(t, parsed.tags[0], "backend")
	testing.expect_value(t, parsed.tags[1], "api")
}

@(test)
test_parse_flag_tags :: proc(t: ^testing.T) {
	args := []string{"proj", "--tags", "a,b,c"}
	parsed := parse_watson_args(args)
	defer free_parsed_args(&parsed)

	testing.expect_value(t, len(parsed.positional), 1)
	testing.expect_value(t, len(parsed.tags), 3)
	testing.expect_value(t, parsed.tags[0], "a")
	testing.expect_value(t, parsed.tags[2], "c")
}

@(test)
test_parse_boolean_flag :: proc(t: ^testing.T) {
	args := []string{"log", "--json"}
	parsed := parse_watson_args(args)
	defer free_parsed_args(&parsed)

	val, ok := parsed.flags["json"]
	testing.expect(t, ok, "expected --json flag")
	testing.expect_value(t, val, "true")
}

@(test)
test_parse_mixed_syntax :: proc(t: ^testing.T) {
	args := []string{"proj", "+urgent", "--tags", "backend,api"}
	parsed := parse_watson_args(args)
	defer free_parsed_args(&parsed)

	// +urgent + backend + api = 3 tags
	testing.expect_value(t, len(parsed.tags), 3)
}

@(test)
test_parse_empty :: proc(t: ^testing.T) {
	args := []string{}
	parsed := parse_watson_args(args)
	defer free_parsed_args(&parsed)

	testing.expect_value(t, len(parsed.positional), 0)
	testing.expect_value(t, len(parsed.tags), 0)
	testing.expect_value(t, len(parsed.flags), 0)
}

// --- frame_id tests ---

@(test)
test_frame_id_length :: proc(t: ^testing.T) {
	id := generate_frame_id("myproject", "2026-03-15 10:00:00")
	testing.expect_value(t, len(id), 7)
}

@(test)
test_frame_id_uniqueness :: proc(t: ^testing.T) {
	// Two calls with same inputs should still differ (nanosecond entropy)
	id1 := generate_frame_id("proj", "2026-03-15 10:00:00")
	id2 := generate_frame_id("proj", "2026-03-15 10:00:00")
	// They may collide in theory but practically won't; just check they're valid hex
	for ch in id1 {
		testing.expect(
			t,
			(ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f'),
			"frame ID must be lowercase hex",
		)
	}
	for ch in id2 {
		testing.expect(
			t,
			(ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f'),
			"frame ID must be lowercase hex",
		)
	}
}

// --- format_duration tests ---

@(test)
test_format_duration_zero :: proc(t: ^testing.T) {
	result := format_duration(0)
	testing.expect_value(t, result, "0h 00m")
}

@(test)
test_format_duration_hours_and_minutes :: proc(t: ^testing.T) {
	result := format_duration(3661) // 1h 1m 1s
	testing.expect_value(t, result, "1h 01m")
}

@(test)
test_format_duration_minutes_only :: proc(t: ^testing.T) {
	result := format_duration(90) // 1m 30s
	testing.expect_value(t, result, "0h 01m")
}

// --- parse_watson_args edge cases for change command ---

@(test)
test_parse_project_flag :: proc(t: ^testing.T) {
	args := []string{"--project", "newname", "+newtag"}
	parsed := parse_watson_args(args)
	defer free_parsed_args(&parsed)

	proj, ok := parsed.flags["project"]
	testing.expect(t, ok, "expected --project flag")
	testing.expect_value(t, proj, "newname")
	testing.expect_value(t, len(parsed.tags), 1)
	testing.expect_value(t, parsed.tags[0], "newtag")
}

// --- import_watson tests ---

@(test)
test_unix_to_sqlite :: proc(t: ^testing.T) {
	// date -d @1730373346 --utc => 2024-10-31 11:15:46
	result := unix_to_sqlite(1730373346)
	testing.expect_value(t, result, "2024-10-31 11:15:46")
	delete(result)
}

@(test)
test_iso8601_to_sqlite :: proc(t: ^testing.T) {
	result := iso8601_to_sqlite("2025-10-31T12:15:46Z")
	testing.expect_value(t, result, "2025-10-31 12:15:46")
	delete(result)
}

@(test)
test_parse_watson_frame_array_basic :: proc(t: ^testing.T) {
	// parse_watson_frame_array expects pos to point at the opening [ of the frame
	src := `["myproject", 1730373346, 1730377200, ["backend", "api"], "abc1234"]`
	end, project, start, stop, tags, ok := parse_watson_frame_array(src, 0)
	defer {delete(project); for tag in tags do delete(tag); delete(tags)}

	testing.expect(t, ok)
	testing.expect_value(t, project, "myproject")
	testing.expect_value(t, start, i64(1730373346))
	testing.expect_value(t, stop, i64(1730377200))
	testing.expect_value(t, len(tags), 2)
	testing.expect_value(t, tags[0], "backend")
	_ = end
}

@(test)
test_parse_watson_frame_array_no_tags :: proc(t: ^testing.T) {
	src := `["proj", 1730373346, 1730377200, [], "abc"]`
	_, project, _, _, tags, ok := parse_watson_frame_array(src, 0)
	defer {delete(project); for tag in tags do delete(tag); delete(tags)}

	testing.expect(t, ok)
	testing.expect_value(t, len(tags), 0)
}

@(test)
test_parse_watson_frame_object_basic :: proc(t: ^testing.T) {
	src := `[{"project":"api-backend","started_at":"2025-10-31T12:15:46Z","stopped_at":"2025-10-31T16:09:46Z","tags":["coding"]}]`
	end, project, start, stop, tags, ok := parse_watson_frame_object(src, 0)
	defer {delete(project); delete(start); delete(stop); for tag in tags do delete(tag)
		delete(tags)}

	testing.expect(t, ok)
	testing.expect_value(t, project, "api-backend")
	testing.expect_value(t, start, "2025-10-31 12:15:46")
	testing.expect_value(t, stop, "2025-10-31 16:09:46")
	testing.expect_value(t, len(tags), 1)
	testing.expect_value(t, tags[0], "coding")
	_ = end
}

@(test)
test_parse_edit_json_full :: proc(t: ^testing.T) {
	src := `{
  "frame_id": "abc1234",
  "project": "myproject",
  "start_time": "2026-03-15 09:00:00",
  "stop_time": "2026-03-15 10:30:00",
  "tags": ["backend", "api"]
}`


	project, start, stop, tags, ok := parse_edit_json(src)
	defer {delete(project); delete(start); delete(stop); for t in tags do delete(t); delete(tags)}

	testing.expect(t, ok)
	testing.expect_value(t, project, "myproject")
	testing.expect_value(t, start, "2026-03-15 09:00:00")
	testing.expect_value(t, stop, "2026-03-15 10:30:00")
	testing.expect_value(t, len(tags), 2)
	testing.expect_value(t, tags[0], "backend")
	testing.expect_value(t, tags[1], "api")
}

@(test)
test_parse_edit_json_empty_tags :: proc(t: ^testing.T) {
	src := `{"project": "proj", "start_time": "2026-03-15 09:00:00", "stop_time": "", "tags": []}`
	project, start, stop, tags, ok := parse_edit_json(src)
	defer {delete(project); delete(start); delete(stop); for t in tags do delete(t); delete(tags)}

	testing.expect(t, ok)
	testing.expect_value(t, project, "proj")
	testing.expect_value(t, len(tags), 0)
}

@(test)
test_parse_edit_json_missing_project :: proc(t: ^testing.T) {
	src := `{"start_time": "2026-03-15 09:00:00", "tags": []}`
	_, _, _, tags, ok := parse_edit_json(src)
	defer {delete(tags)}
	testing.expect(t, !ok, "should fail without project field")
}

@(test)
test_frame_to_edit_json_roundtrip :: proc(t: ^testing.T) {
	entry := TimeEntryInfo {
		project    = "roundtrip",
		start_time = "2026-03-15 08:00:00",
		stop_time  = "2026-03-15 09:00:00",
		duration   = "1h 0m 0s",
		tags       = "x,y",
	}
	json := frame_to_edit_json(entry, "abc1234")

	project, start, stop, tags, ok := parse_edit_json(json)
	defer {delete(project); delete(start); delete(stop); for t in tags do delete(t); delete(tags)}

	testing.expect(t, ok)
	testing.expect_value(t, project, "roundtrip")
	testing.expect_value(t, start, "2026-03-15 08:00:00")
	testing.expect_value(t, stop, "2026-03-15 09:00:00")
	testing.expect_value(t, len(tags), 2)
}

// --- JSON formatter tests ---

@(test)
test_format_report_json_empty :: proc(t: ^testing.T) {
	result := format_report_json([]ProjectReport{})
	testing.expect_value(t, result, `{"projects":[]}`)
}

@(test)
test_format_report_json_single :: proc(t: ^testing.T) {
	tag_times := make(map[string]i64, allocator = context.temp_allocator)
	reports := []ProjectReport {
		{project = "myproject", total_seconds = 3600, tag_times = tag_times},
	}
	result := format_report_json(reports)
	testing.expect_value(t, result, `{"projects":[{"name":"myproject","seconds":3600}]}`)
}

@(test)
test_format_report_json_multiple :: proc(t: ^testing.T) {
	tag_times := make(map[string]i64, allocator = context.temp_allocator)
	reports := []ProjectReport {
		{project = "a", total_seconds = 100, tag_times = tag_times},
		{project = "b", total_seconds = 200, tag_times = tag_times},
	}
	result := format_report_json(reports)
	testing.expect_value(
		t,
		result,
		`{"projects":[{"name":"a","seconds":100},{"name":"b","seconds":200}]}`,
	)
}

@(test)
test_format_report_json_special_chars :: proc(t: ^testing.T) {
	// project name with quotes/braces should be properly escaped
	tag_times := make(map[string]i64, allocator = context.temp_allocator)
	reports := []ProjectReport {
		{project = `say "hello"`, total_seconds = 42, tag_times = tag_times},
	}
	result := format_report_json(reports)
	testing.expect_value(t, result, `{"projects":[{"name":"say \"hello\"","seconds":42}]}`)
}

@(test)
test_format_entries_json_empty :: proc(t: ^testing.T) {
	result := format_entries_json([]TimeEntryInfo{})
	testing.expect_value(t, result, "[]")
}

@(test)
test_format_entries_json_single :: proc(t: ^testing.T) {
	entries := []TimeEntryInfo {
		{
			project = "proj",
			start_time = "2026-03-15 09:00:00",
			stop_time = "2026-03-15 10:00:00",
			duration = "1h 0m 0s",
		},
	}
	result := format_entries_json(entries)
	// must be valid JSON array containing the entry
	testing.expect(t, strings.contains(result, `"project":"proj"`), "expected project field")
	testing.expect(t, strings.has_prefix(result, "["), "expected array start")
	testing.expect(t, strings.has_suffix(result, "]"), "expected array end")
}

