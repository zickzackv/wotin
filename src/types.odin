package main

import "core:time"

// Frame represents a time tracking entry
// Inspired by Watson's frame concept
Frame :: struct {
    id: string,
    project: string,
    started_at: time.Time,
    stopped_at: Maybe(time.Time),
    tags: [dynamic]string,
}

// Project represents a tracked project
Project :: struct {
    name: string,
    total_time: time.Duration,
}

// Tag represents a category or label
Tag :: struct {
    name: string,
    count: int,
}
