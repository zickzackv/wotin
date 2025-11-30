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
projects := []string{
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

tags := []string{
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
generate_random_frame :: proc(id: int, base_time: time.Time) -> Frame {
    // Random project
    project := projects[rand.int31_max(i32(len(projects)))]

    // Random start time within the last 30 days
    days_ago := rand.int31_max(30)
    hours_offset := rand.int31_max(24)
    minutes_offset := rand.int31_max(60)

    start_offset := time.Duration(days_ago) * 24 * time.Hour +
                    time.Duration(hours_offset) * time.Hour +
                    time.Duration(minutes_offset) * time.Minute

    started_at := time.time_add(base_time, -start_offset)

    // Random duration between 15 minutes and 8 hours
    duration_minutes := 15 + rand.int31_max(8 * 60 - 15)
    stopped_at := time.time_add(started_at, time.Duration(duration_minutes) * time.Minute)

    // Random number of tags (0-3)
    tag_count := rand.int31_max(4)
    frame_tags := make([dynamic]string, 0, tag_count)
    defer delete(frame_tags)

    // Add random unique tags
    used_tags := make(map[string]bool)
    defer delete(used_tags)

    for i := 0; i < int(tag_count); i += 1 {
        tag_idx := rand.int31_max(i32(len(tags)))
        tag := tags[tag_idx]

        if tag not_in used_tags {
            append(&frame_tags, tag)
            used_tags[tag] = true
        }
    }

    // Convert tags to slice
    tags_slice := make([]string, len(frame_tags))
    copy(tags_slice, frame_tags[:])

    // Convert time.Time to datetime components for formatting
    started_dt, _ := time.time_to_datetime(started_at)
    stopped_dt, _ := time.time_to_datetime(stopped_at)

    // Format timestamps as ISO 8601
    started_str := fmt.aprintf("%04d-%02d-%02dT%02d:%02d:%02dZ",
        started_dt.date.year, started_dt.date.month, started_dt.date.day,
        started_dt.time.hour, started_dt.time.minute, started_dt.time.second)

    stopped_str := fmt.aprintf("%04d-%02d-%02dT%02d:%02d:%02dZ",
        stopped_dt.date.year, stopped_dt.date.month, stopped_dt.date.day,
        stopped_dt.time.hour, stopped_dt.time.minute, stopped_dt.time.second)

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
        frame := generate_random_frame(i + 1, base_time)
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
