package main

import "core:encoding/json"
import "core:fmt"
import "core:math/rand"
import "core:os"
import "core:time"
import "core:strings"
import "core:mem"

// Frame represents a time tracking entry
Frame :: struct {
    id: string,
    project: string,
    started_at: string,  // ISO 8601 format for JSON compatibility
    stopped_at: string,  // ISO 8601 format
    tags: []string,
}

// Sample data for generation
PROJECTS :: []string{
    "wotin",
    "website-redesign",
    "mobile-app",
    "api-backend",
    "documentation",
    "client-project-alpha",
    "client-project-beta",
    "research",
    "personal-blog",
    "open-source-contrib",
}

TAGS :: []string{
    "coding",
    "meeting",
    "debugging",
    "planning",
    "review",
    "testing",
    "documentation",
    "research",
    "design",
    "deployment",
    "maintenance",
    "learning",
}

// Generate a random frame
generate_random_frame :: proc(id: int, base_time: time.Time, r: ^rand.Rand) -> Frame {
    // Random project
    project := PROJECTS[rand.int31_max(i32(len(PROJECTS)), r)]
    
    // Random start time within the last 30 days
    days_ago := rand.int31_max(30, r)
    hours_offset := rand.int31_max(24, r)
    minutes_offset := rand.int31_max(60, r)
    
    start_offset := time.Duration(days_ago) * 24 * time.Hour + 
                    time.Duration(hours_offset) * time.Hour + 
                    time.Duration(minutes_offset) * time.Minute
    
    started_at := time.time_add(base_time, -start_offset)
    
    // Random duration between 15 minutes and 8 hours
    duration_minutes := 15 + rand.int31_max(8 * 60 - 15, r)
    stopped_at := time.time_add(started_at, time.Duration(duration_minutes) * time.Minute)
    
    // Random number of tags (0-3)
    tag_count := rand.int31_max(4, r)
    tags := make([dynamic]string, 0, tag_count)
    defer delete(tags)
    
    // Add random unique tags
    used_tags := make(map[string]bool)
    defer delete(used_tags)
    
    for i := 0; i < int(tag_count); i += 1 {
        tag_idx := rand.int31_max(i32(len(TAGS)), r)
        tag := TAGS[tag_idx]
        
        if tag not_in used_tags {
            append(&tags, tag)
            used_tags[tag] = true
        }
    }
    
    // Convert tags to slice
    tags_slice := make([]string, len(tags))
    copy(tags_slice, tags[:])
    
    // Format timestamps as ISO 8601
    started_str := fmt.aprintf("%04d-%02d-%02dT%02d:%02d:%02dZ",
        started_at.year, started_at.month, started_at.day,
        started_at.hour, started_at.minute, started_at.second)
    
    stopped_str := fmt.aprintf("%04d-%02d-%02dT%02d:%02d:%02dZ",
        stopped_at.year, stopped_at.month, stopped_at.day,
        stopped_at.hour, stopped_at.minute, stopped_at.second)
    
    frame_id := fmt.aprintf("frame_%05d", id)
    
    return Frame{
        id = frame_id,
        project = project,
        started_at = started_str,
        stopped_at = stopped_str,
        tags = tags_slice,
    }
}

main :: proc() {
    // Initialize random number generator with current time
    r := rand.create(u64(time.now()._nsec))
    
    fmt.println("Generating 100 random time tracking frames...")
    
    // Generate frames
    frames := make([dynamic]Frame, 0, 100)
    defer {
        for frame in frames {
            delete(frame.id)
            delete(frame.started_at)
            delete(frame.stopped_at)
            delete(frame.tags)
        }
        delete(frames)
    }
    
    base_time := time.now()
    
    for i in 0..<100 {
        frame := generate_random_frame(i + 1, base_time, &r)
        append(&frames, frame)
    }
    
    fmt.printf("Generated %d frames\n", len(frames))
    
    // Convert to JSON
    json_data, json_err := json.marshal(frames[:], {pretty = true, use_spaces = true, spaces = 2})
    if json_err != nil {
        fmt.eprintln("Error marshaling JSON:", json_err)
        os.exit(1)
    }
    defer delete(json_data)
    
    // Write to file
    output_file := "test_frames.json"
    write_ok := os.write_entire_file(output_file, json_data)
    
    if !write_ok {
        fmt.eprintln("Error writing to file:", output_file)
        os.exit(1)
    }
    
    fmt.printf("Successfully wrote test data to %s\n", output_file)
    fmt.printf("File size: %d bytes\n", len(json_data))
    
    // Print summary statistics
    project_counts := make(map[string]int)
    defer delete(project_counts)
    
    tag_counts := make(map[string]int)
    defer delete(tag_counts)
    
    for frame in frames {
        project_counts[frame.project] += 1
        for tag in frame.tags {
            tag_counts[tag] += 1
        }
    }
    
    fmt.println("\n--- Summary Statistics ---")
    fmt.println("\nFrames per project:")
    for project, count in project_counts {
        fmt.printf("  %s: %d\n", project, count)
    }
    
    fmt.println("\nTag usage:")
    for tag, count in tag_counts {
        fmt.printf("  %s: %d\n", tag, count)
    }
}
