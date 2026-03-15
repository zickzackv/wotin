package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
import os2 "core:os/os2"
import "core:strings"

// JSON struct for editing a frame
EditFrameJson :: struct {
	frame_id:   string `json:"frame_id"`,
	project:    string `json:"project"`,
	start_time: string `json:"start_time"`,
	stop_time:  string `json:"stop_time"`,
	tags:       []string `json:"tags"`,
}

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
	json_str := frame_to_edit_json(entry, frame_id)
	if !os.write_entire_file(tmp_path, transmute([]byte)json_str) {
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

	if !change_entry(frame_id, new_project, new_tags[:], true) {
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

frame_to_edit_json :: proc(entry: TimeEntryInfo, frame_id: string) -> string {
	tags: []string
	if len(entry.tags) > 0 {
		parts := strings.split(entry.tags, ",", context.temp_allocator)
		for &p in parts do p = strings.trim_space(p)
		tags = parts
	}
	j := EditFrameJson {
		frame_id   = frame_id,
		project    = entry.project,
		start_time = entry.start_time,
		stop_time  = entry.stop_time,
		tags       = tags,
	}
	opt := json.Marshal_Options {
		pretty = true,
	}
	data, err := json.marshal(j, opt, context.temp_allocator)
	if err != nil do return "{}"
	return string(data)
}

parse_edit_json :: proc(
	src: string,
) -> (
	project, start_time, stop_time: string,
	tags: [dynamic]string,
	ok: bool,
) {
	tags = make([dynamic]string)
	ef: EditFrameJson
	if err := json.unmarshal(transmute([]byte)src, &ef); err != nil {
		delete(tags)
		return "", "", "", tags, false
	}
	defer {
		delete(ef.frame_id)
		delete(ef.start_time)
		delete(ef.stop_time)
		delete(ef.project)
		for t in ef.tags do delete(t)
		delete(ef.tags)
	}
	if len(ef.project) == 0 {
		delete(tags)
		return "", "", "", tags, false
	}
	for t in ef.tags do append(&tags, strings.clone(t))
	return strings.clone(ef.project),
		strings.clone(ef.start_time),
		strings.clone(ef.stop_time),
		tags,
		true
}
