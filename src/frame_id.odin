package main

import "core:fmt"
import "core:hash"
import "core:time"

// Generate a 7-character frame ID similar to git short hashes
generate_frame_id :: proc(project: string, start_time: string) -> string {
	now := time.now()
	seed := u32(now._nsec & 0xFFFFFFFF)
	combined := fmt.tprintf("%s%s", project, start_time)
	h := hash.fnv32a(transmute([]byte)combined, seed)
	return fmt.tprintf("%07x", h)[:7]
}
