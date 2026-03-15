package main

import "core:fmt"
import "core:time"
import "core:strings"

// Generate a 7-character frame ID similar to git short hashes
generate_frame_id :: proc(project: string, start_time: string) -> string {
	// Create a unique string from project, start time, and current nanoseconds
	now := time.now()
	unique_val := u64(now._nsec) ~ u64(len(project)) ~ u64(len(start_time))
	
	// Simple hash function
	hash := unique_val
	hash = hash ~ (hash << 13)
	hash = hash ~ (hash >> 7)
	hash = hash ~ (hash << 17)
	
	// Convert to hex string (7 characters)
	hex_chars := "0123456789abcdef"
	result := make([]byte, 7, context.temp_allocator)
	for i := 0; i < 7; i += 1 {
		shift := u64(i * 4)
		result[i] = hex_chars[(hash >> shift) & 0xF]
	}
	
	return string(result)
}
