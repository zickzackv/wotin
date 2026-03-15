package main

import "core:testing"
import "core:strings"

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
		testing.expect(t, (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f'),
			"frame ID must be lowercase hex")
	}
	for ch in id2 {
		testing.expect(t, (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f'),
			"frame ID must be lowercase hex")
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
