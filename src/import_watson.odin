package main

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:time"

// Import Watson frames file.
// Watson format: JSON array of arrays: [project, start_unix, stop_unix, [tags...], id]
// Returns number of imported entries.
import_watson_frames :: proc(path: string) -> (imported: int, skipped: int, ok: bool) {
	data, read_ok := os.read_entire_file(path)
	if !read_ok {
		fmt.fprintf(os.stderr, "Error: cannot read file '%s'\n", path)
		return 0, 0, false
	}
	defer delete(data)

	src := strings.trim_space(string(data))
	if len(src) == 0 || src[0] != '[' {
		fmt.eprintln("Error: expected a JSON array")
		return 0, 0, false
	}

	// Walk through top-level array elements
	// Each element is either [...] (Watson native) or {...} (object format)
	pos := 1 // skip opening [
	for {
		pos = skip_whitespace(src, pos)
		if pos >= len(src) do break
		if src[pos] == ']' do break
		if src[pos] == ',' {pos += 1; continue}

		if src[pos] == '[' {
			// Watson native: [project, start, stop, [tags...], id]
			end, project, start_unix, stop_unix, tags, parse_ok := parse_watson_frame_array(
				src,
				pos,
			)
			pos = end
			if !parse_ok {skipped += 1; continue}
			defer {delete(project); for t in tags do delete(t); delete(tags)}

			start_str := unix_to_sqlite(start_unix)
			stop_str := unix_to_sqlite(stop_unix)
			if add_time_entry(project, start_str, stop_str, tags[:]) {
				imported += 1
			} else {
				skipped += 1
			}
		} else if src[pos] == '{' {
			// Object format: {"project":..., "started_at":..., "stopped_at":..., "tags":[...]}
			end, project, start_str, stop_str, tags, parse_ok := parse_watson_frame_object(
				src,
				pos,
			)
			pos = end
			if !parse_ok {skipped += 1; continue}
			defer {delete(project); delete(start_str); delete(stop_str); for t in tags do delete(t)
				delete(tags)}

			if add_time_entry(project, start_str, stop_str, tags[:]) {
				imported += 1
			} else {
				skipped += 1
			}
		} else {
			pos += 1
		}
	}
	return imported, skipped, true
}

skip_whitespace :: proc(src: string, pos: int) -> int {
	p := pos
	for p < len(src) && (src[p] == ' ' || src[p] == '\t' || src[p] == '\n' || src[p] == '\r') {
		p += 1
	}
	return p
}

// Find matching closing bracket/brace, respecting nesting and strings
find_closing :: proc(src: string, pos: int, open, close: byte) -> int {
	depth := 0
	i := pos
	in_string := false
	for i < len(src) {
		c := src[i]
		if in_string {
			if c == '\\' {i += 2; continue}
			if c == '"' do in_string = false
		} else {
			if c == '"' {in_string = true} else if c == open {depth += 1} else if c == close {
				depth -= 1
				if depth == 0 do return i
			}
		}
		i += 1
	}
	return -1
}

// Extract a JSON string value starting at pos (must point at opening ")
extract_json_string :: proc(
	src: string,
	pos: int,
	allocator := context.allocator,
) -> (
	val: string,
	end: int,
	ok: bool,
) {
	if pos >= len(src) || src[pos] != '"' do return "", pos, false
	i := pos + 1
	b := strings.builder_make(context.temp_allocator)
	for i < len(src) {
		c := src[i]
		if c == '\\' && i + 1 < len(src) {
			switch src[i + 1] {
			case '"':
				strings.write_byte(&b, '"')
			case '\\':
				strings.write_byte(&b, '\\')
			case 'n':
				strings.write_byte(&b, '\n')
			case 't':
				strings.write_byte(&b, '\t')
			case:
				strings.write_byte(&b, src[i + 1])
			}
			i += 2
			continue
		}
		if c == '"' {
			return strings.clone(strings.to_string(b), allocator), i + 1, true
		}
		strings.write_byte(&b, c)
		i += 1
	}
	return "", i, false
}

// Parse Watson native array frame: [project, start_unix, stop_unix, [tags...], id]
parse_watson_frame_array :: proc(
	src: string,
	pos: int,
) -> (
	end: int,
	project: string,
	start_unix: i64,
	stop_unix: i64,
	tags: [dynamic]string,
	ok: bool,
) {
	tags = make([dynamic]string)
	closing := find_closing(src, pos, '[', ']')
	if closing < 0 do return pos + 1, "", 0, 0, tags, false
	end = closing + 1

	inner := src[pos + 1:closing]
	// tokenize: string, number, number, array, string
	p := 0
	p = skip_whitespace(inner, p)

	// project
	if p >= len(inner) || inner[p] != '"' do return end, "", 0, 0, tags, false
	proj, after_proj, proj_ok := extract_json_string(inner, p)
	if !proj_ok do return end, "", 0, 0, tags, false
	project = proj
	p = skip_whitespace(inner, after_proj)
	if p < len(inner) && inner[p] == ',' do p += 1

	// start_unix
	p = skip_whitespace(inner, p)
	num_end := p
	for num_end < len(inner) && (inner[num_end] >= '0' && inner[num_end] <= '9') do num_end += 1
	start_unix, _ = strconv.parse_i64(inner[p:num_end])
	p = num_end
	p = skip_whitespace(inner, p)
	if p < len(inner) && inner[p] == ',' do p += 1

	// stop_unix
	p = skip_whitespace(inner, p)
	num_end = p
	for num_end < len(inner) && (inner[num_end] >= '0' && inner[num_end] <= '9') do num_end += 1
	stop_unix, _ = strconv.parse_i64(inner[p:num_end])
	p = num_end
	p = skip_whitespace(inner, p)
	if p < len(inner) && inner[p] == ',' do p += 1

	// tags array
	p = skip_whitespace(inner, p)
	if p < len(inner) && inner[p] == '[' {
		tag_close := find_closing(inner, p, '[', ']')
		if tag_close > 0 {
			tag_inner := inner[p + 1:tag_close]
			tp := 0
			for {
				tp = skip_whitespace(tag_inner, tp)
				if tp >= len(tag_inner) do break
				if tag_inner[tp] == ',' {tp += 1; continue}
				if tag_inner[tp] != '"' do break
				tag, after_tag, tag_ok := extract_json_string(tag_inner, tp)
				if !tag_ok do break
				if len(tag) > 0 do append(&tags, tag)
				tp = after_tag
			}
			p = tag_close + 1
		}
	}

	return end, project, start_unix, stop_unix, tags, true
}

// Parse object-format frame: {"project":..., "started_at":..., "stopped_at":..., "tags":[...]}
parse_watson_frame_object :: proc(
	src: string,
	pos: int,
) -> (
	end: int,
	project, start_str, stop_str: string,
	tags: [dynamic]string,
	ok: bool,
) {
	tags = make([dynamic]string)
	closing := find_closing(src, pos, '{', '}')
	if closing < 0 do return pos + 1, "", "", "", tags, false
	end = closing + 1

	inner := src[pos + 1:closing]

	get_field :: proc(inner, key: string) -> string {
		needle := fmt.tprintf("\"%s\"", key)
		idx := strings.index(inner, needle)
		if idx < 0 do return ""
		rest := strings.trim_space(inner[idx + len(needle):])
		if len(rest) == 0 || rest[0] != ':' do return ""
		rest = strings.trim_space(rest[1:])
		if len(rest) == 0 || rest[0] != '"' do return ""
		val, _, val_ok := extract_json_string(rest, 0, context.temp_allocator)
		if !val_ok do return ""
		return val
	}

	project_tmp := get_field(inner, "project")
	if len(project_tmp) == 0 do return end, "", "", "", tags, false
	project = strings.clone(project_tmp)

	start_raw := get_field(inner, "started_at")
	stop_raw := get_field(inner, "stopped_at")
	start_str = iso8601_to_sqlite(start_raw)
	stop_str = iso8601_to_sqlite(stop_raw)

	// Parse tags array
	tags_key := "\"tags\":"
	ti := strings.index(inner, tags_key)
	if ti >= 0 {
		rest := strings.trim_space(inner[ti + len(tags_key):])
		if len(rest) > 0 && rest[0] == '[' {
			tag_close := find_closing(rest, 0, '[', ']')
			if tag_close > 0 {
				tag_inner := rest[1:tag_close]
				tp := 0
				for {
					tp = skip_whitespace(tag_inner, tp)
					if tp >= len(tag_inner) do break
					if tag_inner[tp] == ',' {tp += 1; continue}
					if tag_inner[tp] != '"' do break
					tag, after_tag, tag_ok := extract_json_string(tag_inner, tp)
					if !tag_ok do break
					if len(tag) > 0 do append(&tags, tag)
					tp = after_tag
				}
			}
		}
	}

	return end, project, start_str, stop_str, tags, true
}

// Convert Unix timestamp to SQLite datetime string (UTC)
unix_to_sqlite :: proc(unix: i64) -> string {
	t := time.Time {
		_nsec = unix * 1_000_000_000,
	}
	y, m, d := time.date(t)
	h, mi, s := time.clock(t)
	return fmt.aprintf("%04d-%02d-%02d %02d:%02d:%02d", y, int(m), d, h, mi, s)
}

// Convert ISO8601 "2025-10-31T12:15:46Z" to "2025-10-31 12:15:46"
iso8601_to_sqlite :: proc(s: string) -> string {
	if len(s) < 19 do return s
	// Replace T with space, strip trailing Z/timezone
	b := strings.clone(s[:19])
	if b[10] == 'T' {
		bs := transmute([]byte)b
		bs[10] = ' '
	}
	return b
}
