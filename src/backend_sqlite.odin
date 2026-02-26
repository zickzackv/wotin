package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:c"

db: ^Sqlite3

get_db_path :: proc() -> string {
    config_dir := get_config_dir()
    return filepath.join({config_dir, "timetracking.db"})
}

init_database :: proc() -> bool {
    config_dir := get_config_dir()
    os.make_directory(config_dir)
    
    db_path := get_db_path()
    db_path_cstr := strings.clone_to_cstring(db_path, context.temp_allocator)
    
    if sqlite3_open(db_path_cstr, &db) != SQLITE_OK {
        fmt.eprintln("Failed to open database")
        return false
    }
    
    schema := `
CREATE TABLE IF NOT EXISTS projects (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS tags (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS time_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id INTEGER NOT NULL,
    start_time TEXT NOT NULL,
    stop_time TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id) REFERENCES projects(id)
);

CREATE TABLE IF NOT EXISTS time_entry_tags (
    time_entry_id INTEGER NOT NULL,
    tag_id INTEGER NOT NULL,
    PRIMARY KEY (time_entry_id, tag_id),
    FOREIGN KEY (time_entry_id) REFERENCES time_entries(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_time_entries_project ON time_entries(project_id);
CREATE INDEX IF NOT EXISTS idx_time_entries_start ON time_entries(start_time);
CREATE INDEX IF NOT EXISTS idx_time_entry_tags_tag ON time_entry_tags(tag_id);
`
    
    schema_cstr := strings.clone_to_cstring(schema, context.temp_allocator)
    errmsg: cstring
    
    if sqlite3_exec(db, schema_cstr, nil, nil, &errmsg) != SQLITE_OK {
        fmt.eprintln("Failed to create schema:", errmsg)
        return false
    }
    
    return true
}

close_database :: proc() {
    if db != nil {
        sqlite3_close(db)
    }
}

get_or_create_project :: proc(name: string) -> (id: i64, ok: bool) {
    name_cstr := strings.clone_to_cstring(name, context.temp_allocator)
    
    // Try to insert
    insert_sql := "INSERT OR IGNORE INTO projects (name) VALUES (?)"
    insert_sql_cstr := strings.clone_to_cstring(insert_sql, context.temp_allocator)
    
    stmt: ^Sqlite3_Stmt
    if sqlite3_prepare_v2(db, insert_sql_cstr, -1, &stmt, nil) != SQLITE_OK {
        return 0, false
    }
    defer sqlite3_finalize(stmt)
    
    sqlite3_bind_text(stmt, 1, name_cstr, -1, nil)
    sqlite3_step(stmt)
    
    // Get the ID
    select_sql := "SELECT id FROM projects WHERE name = ?"
    select_sql_cstr := strings.clone_to_cstring(select_sql, context.temp_allocator)
    
    stmt2: ^Sqlite3_Stmt
    if sqlite3_prepare_v2(db, select_sql_cstr, -1, &stmt2, nil) != SQLITE_OK {
        return 0, false
    }
    defer sqlite3_finalize(stmt2)
    
    sqlite3_bind_text(stmt2, 1, name_cstr, -1, nil)
    
    if sqlite3_step(stmt2) == SQLITE_ROW {
        return sqlite3_column_int64(stmt2, 0), true
    }
    
    return 0, false
}

get_or_create_tag :: proc(name: string) -> (id: i64, ok: bool) {
    name_cstr := strings.clone_to_cstring(name, context.temp_allocator)
    
    // Try to insert
    insert_sql := "INSERT OR IGNORE INTO tags (name) VALUES (?)"
    insert_sql_cstr := strings.clone_to_cstring(insert_sql, context.temp_allocator)
    
    stmt: ^Sqlite3_Stmt
    if sqlite3_prepare_v2(db, insert_sql_cstr, -1, &stmt, nil) != SQLITE_OK {
        return 0, false
    }
    defer sqlite3_finalize(stmt)
    
    sqlite3_bind_text(stmt, 1, name_cstr, -1, nil)
    sqlite3_step(stmt)
    
    // Get the ID
    select_sql := "SELECT id FROM tags WHERE name = ?"
    select_sql_cstr := strings.clone_to_cstring(select_sql, context.temp_allocator)
    
    stmt2: ^Sqlite3_Stmt
    if sqlite3_prepare_v2(db, select_sql_cstr, -1, &stmt2, nil) != SQLITE_OK {
        return 0, false
    }
    defer sqlite3_finalize(stmt2)
    
    sqlite3_bind_text(stmt2, 1, name_cstr, -1, nil)
    
    if sqlite3_step(stmt2) == SQLITE_ROW {
        return sqlite3_column_int64(stmt2, 0), true
    }
    
    return 0, false
}


start_tracking :: proc(project: string, tags: []string) -> bool {
    // Check for existing running entry
    check_sql := "SELECT id FROM time_entries WHERE stop_time IS NULL"
    check_sql_cstr := strings.clone_to_cstring(check_sql, context.temp_allocator)
    
    stmt: ^Sqlite3_Stmt
    if sqlite3_prepare_v2(db, check_sql_cstr, -1, &stmt, nil) == SQLITE_OK {
        if sqlite3_step(stmt) == SQLITE_ROW {
            sqlite3_finalize(stmt)
            fmt.eprintln("Error: A timer is already running. Stop it first.")
            return false
        }
        sqlite3_finalize(stmt)
    }
    
    // Get or create project
    project_id, ok := get_or_create_project(project)
    if !ok {
        fmt.eprintln("Failed to get/create project")
        return false
    }
    
    // Insert time entry
    insert_sql := "INSERT INTO time_entries (project_id, start_time) VALUES (?, datetime('now'))"
    insert_sql_cstr := strings.clone_to_cstring(insert_sql, context.temp_allocator)
    
    stmt2: ^Sqlite3_Stmt
    if sqlite3_prepare_v2(db, insert_sql_cstr, -1, &stmt2, nil) != SQLITE_OK {
        fmt.eprintln("Failed to prepare insert statement")
        return false
    }
    defer sqlite3_finalize(stmt2)
    
    sqlite3_bind_int64(stmt2, 1, project_id)
    
    if sqlite3_step(stmt2) != SQLITE_DONE {
        fmt.eprintln("Failed to insert time entry")
        return false
    }
    
    entry_id := sqlite3_last_insert_rowid(db)
    
    // Insert tags
    for tag in tags {
        tag_id, tag_ok := get_or_create_tag(tag)
        if !tag_ok {
            continue
        }
        
        tag_sql := "INSERT INTO time_entry_tags (time_entry_id, tag_id) VALUES (?, ?)"
        tag_sql_cstr := strings.clone_to_cstring(tag_sql, context.temp_allocator)
        
        tag_stmt: ^Sqlite3_Stmt
        if sqlite3_prepare_v2(db, tag_sql_cstr, -1, &tag_stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(tag_stmt, 1, entry_id)
            sqlite3_bind_int64(tag_stmt, 2, tag_id)
            sqlite3_step(tag_stmt)
            sqlite3_finalize(tag_stmt)
        }
    }
    
    return true
}


stop_tracking :: proc() -> bool {
    // Find running entry
    select_sql := "SELECT id, project_id, start_time FROM time_entries WHERE stop_time IS NULL"
    select_sql_cstr := strings.clone_to_cstring(select_sql, context.temp_allocator)
    
    stmt: ^Sqlite3_Stmt
    if sqlite3_prepare_v2(db, select_sql_cstr, -1, &stmt, nil) != SQLITE_OK {
        fmt.eprintln("Failed to query running entry")
        return false
    }
    defer sqlite3_finalize(stmt)
    
    if sqlite3_step(stmt) != SQLITE_ROW {
        fmt.eprintln("Error: No timer is currently running")
        return false
    }
    
    entry_id := sqlite3_column_int64(stmt, 0)
    
    // Update stop time
    update_sql := "UPDATE time_entries SET stop_time = datetime('now') WHERE id = ?"
    update_sql_cstr := strings.clone_to_cstring(update_sql, context.temp_allocator)
    
    stmt2: ^Sqlite3_Stmt
    if sqlite3_prepare_v2(db, update_sql_cstr, -1, &stmt2, nil) != SQLITE_OK {
        fmt.eprintln("Failed to prepare update statement")
        return false
    }
    defer sqlite3_finalize(stmt2)
    
    sqlite3_bind_int64(stmt2, 1, entry_id)
    
    if sqlite3_step(stmt2) != SQLITE_DONE {
        fmt.eprintln("Failed to update time entry")
        return false
    }
    
    return true
}
