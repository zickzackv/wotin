package main

import "core:fmt"
import "core:os"
import os2 "core:os/os2"
import "core:strings"

// Open a frame in $EDITOR as JSON, apply changes on save.
edit_frame_in_editor :: proc(frame_id: string) -> bool {
	entry, ok := get_entry_by_frame_id(frame_id)
	if !ok {
		fmt.fprintf(os.stderr, "Error: frame '%s' not found\n", frame_id)
		return false
	}
	defer {
		delete(entry.project)
		delete(entry.start_time)
		delete(entry.stop_time)
		delete(entry.tags)
	}

	tmp_path := fmt.tprintf("/tmp/wotin_edit_%s.json", frame_id)
	json := frame_to_edit_json(entry, frame_id)
	if !os.write_entire_file(tmp_path, transmute([]byte)json) {
		fmt.eprintln("Error: could not write temp file")
		return false
	}
	defer os.remove(tmp_path)

	editor := os.get_env("EDITOR")
	if len(editor) == 0 do editor = "vi"

	proc_desc := os2.Process_Desc {
		command = []string{editor, tmp_path},
		stdin   = os2.stdin,
		stdout  = os2.stdout,
		stderr  = os2.stderr,
	}
	p, p_err := os2.process_start(proc_desc)
	if p_err != nil {
		fmt.fprintf(os.stderr, "Error: could not start editor '%s'\n", editor)
		return false
	}
	state, w_err := os2.process_wait(p)
	_ = os2.process_close(p)
	if w_err != nil || state.exit_code != 0 {
		fmt.eprintln("Error: editor exited with error")
		return false
	}

	data, read_ok := os.read_entire_file(tmp_path)
	if !read_ok {
		fmt.eprintln("Error: could not read temp file")
		return false
	}
	defer delete(data)

	new_project, new_start, new_stop, new_tags, parse_ok := parse_edit_json(string(data))
	if !parse_ok {
		fmt.eprintln("Error: invalid JSON in edited file")
		return false
	}
	defer {
		delete(new_project)
		delete(new_start)
		delete(new_stop)
		for t in new_tags do delete(t)
		delete(new_tags)
	}

	has_tags := len(new_tags) > 0
	if !change_entry(frame_id, new_project, new_tags[:], has_tags) {
		fmt.eprintln("Error: failed to update project/tags")
		return false
	}
	if len(new_start) > 0 || len(new_stop) > 0 {
		if !edit_entry_times(frame_id, new_start, new_stop) {
			fmt.eprintln("Error: failed to update times")
			return false
		}
	}
	return true
}

// Produce a human-friendly JSON for editing
frame_to_edit_json :: proc(entry: TimeEntryInfo, frame_id: string) -> string {
	b := strings.builder_make(context.temp_allocator)
	strings.write_string(&b, "{\n")
	fmt.sbprintf(&b, "  \"frame_id\": \"%s\",\n", frame_id)
	fmt.sbprintf(&b, "  \"project\": \"%s\",\n", json_escape(entry.project))
	fmt.sbprintf(&b, "  \"start_time\": \"%s\",\n", entry.start_time)
	fmt.sbprintf(&b, "  \"stop_time\": \"%s\",\n", entry.stop_time)
	fmt.sbprintf(&b, "  \"tags\": [")
	if len(entry.tags) > 0 {
		parts := strings.split(entry.tags, ",", context.temp_allocator)
		for p, i in parts {
			if i > 0 do fmt.sbprintf(&b, ", ")
			fmt.sbprintf(&b, "\"%s\"", strings.trim_space(p))
		}
	}
	fmt.sbprintf(&b, "]\n}\n")
	return strings.to_string(b)
}

// Minimal JSON field extractor — only handles the flat frame format we write above.
// Returns allocated strings; caller must free.
parse_edit_json :: proc(
	src: string,
) -> (
	project, start_time, stop_time: string,
	tags: [dynamic]string,
	ok: bool,
) {
	tags = make([dynamic]string)

	extract_string :: proc(src, key: string) -> (val: string, found: bool) {
		needle := fmt.tprintf("\"%s\":", key)
		idx := strings.index(src, needle)
		if idx < 0 do return "", false
		rest := src[idx + len(needle):]
		rest = strings.trim_space(rest)
		if len(rest) == 0 || rest[0] != '"' do return "", false
		rest = rest[1:]
		end := strings.index(rest, "\"")
		if end < 0 do return "", false
		return strings.clone(rest[:end]), true
	}

	p, p_ok := extract_string(src, "project")
	if !p_ok {delete(tags); return "", "", "", tags, false}
	project = p

	s, _ := extract_string(src, "start_time")
	start_time = s

	st, _ := extract_string(src, "stop_time")
	stop_time = st

	// Parse tags array: find ["a", "b", ...]
	tags_key := "\"tags\":"
	ti := strings.index(src, tags_key)
	if ti >= 0 {
		rest := strings.trim_space(src[ti + len(tags_key):])
		if len(rest) > 0 && rest[0] == '[' {
			rest = rest[1:]
			end_bracket := strings.index(rest, "]")
			if end_bracket >= 0 {
				inner := rest[:end_bracket]
				for len(inner) > 0 {
					inner = strings.trim_space(inner)
					if len(inner) == 0 || inner[0] != '"' do break
					inner = inner[1:]
					end := strings.index(inner, "\"")
					if end < 0 do break
					tag := strings.trim_space(inner[:end])
					if len(tag) > 0 do append(&tags, strings.clone(tag))
					inner = inner[end + 1:]
					inner = strings.trim_left(inner, " \t\n\r,")
				}
			}
		}
	}

	return project, start_time, stop_time, tags, true
}
