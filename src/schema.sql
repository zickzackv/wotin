-- Projects table
CREATE TABLE projects (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Tags table
CREATE TABLE tags (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Time entries
CREATE TABLE time_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id INTEGER NOT NULL,
    start_time TEXT NOT NULL,
    stop_time TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id) REFERENCES projects(id)
);

-- Many-to-many relationship for tags
CREATE TABLE time_entry_tags (
    time_entry_id INTEGER NOT NULL,
    tag_id INTEGER NOT NULL,
    PRIMARY KEY (time_entry_id, tag_id),
    FOREIGN KEY (time_entry_id) REFERENCES time_entries(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
);

-- Indexes for common queries
CREATE INDEX idx_time_entries_project ON time_entries(project_id);
CREATE INDEX idx_time_entries_start ON time_entries(start_time);
CREATE INDEX idx_time_entry_tags_tag ON time_entry_tags(tag_id);
