package main

import "core:strings"
import "core:slice"

// Parsed command arguments
ParsedArgs :: struct {
	positional: [dynamic]string,  // Non-flag, non-tag arguments
	tags: [dynamic]string,         // Arguments starting with +
	flags: map[string]string,      // --flag value pairs
}

// Parse Watson-style arguments: positional args, +tags, and --flags
parse_watson_args :: proc(args: []string, allocator := context.allocator) -> ParsedArgs {
	result := ParsedArgs{
		positional = make([dynamic]string, allocator),
		tags = make([dynamic]string, allocator),
		flags = make(map[string]string, allocator=allocator),
	}
	
	i := 0
	for i < len(args) {
		arg := args[i]
		
		// Check for +tag syntax
		if strings.has_prefix(arg, "+") {
			tag := strings.trim_prefix(arg, "+")
			if len(tag) > 0 {
				append(&result.tags, strings.clone(tag, allocator))
			}
			i += 1
			continue
		}
		
		// Check for --flag syntax
		if strings.has_prefix(arg, "--") {
			flag_name := strings.trim_prefix(arg, "--")
			
			// Check if next arg is the value (not another flag/tag)
			if i + 1 < len(args) && !strings.has_prefix(args[i + 1], "--") && !strings.has_prefix(args[i + 1], "+") {
				result.flags[strings.clone(flag_name, allocator)] = strings.clone(args[i + 1], allocator)
				i += 2
			} else {
				// Boolean flag (no value)
				result.flags[strings.clone(flag_name, allocator)] = "true"
				i += 1
			}
			continue
		}
		
		// Regular positional argument
		append(&result.positional, strings.clone(arg, allocator))
		i += 1
	}
	
	// Also support --tags flag for backward compatibility
	if tags_str, has_tags := result.flags["tags"]; has_tags {
		tag_parts := strings.split(tags_str, ",", context.temp_allocator)
		for tag in tag_parts {
			trimmed := strings.trim_space(tag)
			if len(trimmed) > 0 {
				append(&result.tags, strings.clone(trimmed, allocator))
			}
		}
		delete_key(&result.flags, "tags")
	}
	
	return result
}

// Free parsed args memory
free_parsed_args :: proc(args: ^ParsedArgs) {
	delete(args.positional)
	delete(args.tags)
	delete(args.flags)
}
