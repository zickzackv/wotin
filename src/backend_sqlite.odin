package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

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

	// Migration: Add frame_id column if it doesn't exist (for existing databases)
	// Check if frame_id column exists
	check_col_sql := "SELECT frame_id FROM time_entries LIMIT 1"
	check_col_cstr := strings.clone_to_cstring(check_col_sql, context.temp_allocator)
	check_stmt: ^Sqlite3_Stmt

	// If prepare fails, column doesn't exist, so add it
	if sqlite3_prepare_v2(db, check_col_cstr, -1, &check_stmt, nil) != SQLITE_OK {
		alter_sql := "ALTER TABLE time_entries ADD COLUMN frame_id TEXT"
		alter_cstr := strings.clone_to_cstring(alter_sql, context.temp_allocator)
		sqlite3_exec(db, alter_cstr, nil, nil, nil)

		// Add index
		index_sql := "CREATE INDEX IF NOT EXISTS idx_time_entries_frame_id ON time_entries(frame_id)"
		index_cstr := strings.clone_to_cstring(index_sql, context.temp_allocator)
		sqlite3_exec(db, index_cstr, nil, nil, nil)
	} else {
		sqlite3_finalize(check_stmt)
	}

	// Generate frame IDs for existing entries that don't have one
	backfill_frame_ids()

	return true
}

// Backfill frame IDs for existing entries
backfill_frame_ids :: proc() {
	query := "SELECT id, project_id, start_time FROM time_entries WHERE frame_id IS NULL"
	query_cstr := strings.clone_to_cstring(query, context.temp_allocator)

	stmt: ^Sqlite3_Stmt
	if sqlite3_prepare_v2(db, query_cstr, -1, &stmt, nil) != SQLITE_OK {
		return
	}
	defer sqlite3_finalize(stmt)

	for sqlite3_step(stmt) == SQLITE_ROW {
		entry_id := sqlite3_column_int64(stmt, 0)
		project_id := sqlite3_column_int64(stmt, 1)
		start_time := string(cstring(sqlite3_column_text(stmt, 2)))

		// Get project name
		proj_query := "SELECT name FROM projects WHERE id = ?"
		proj_query_cstr := strings.clone_to_cstring(proj_query, context.temp_allocator)

		proj_stmt: ^Sqlite3_Stmt
		if sqlite3_prepare_v2(db, proj_query_cstr, -1, &proj_stmt, nil) == SQLITE_OK {
			sqlite3_bind_int64(proj_stmt, 1, project_id)
			if sqlite3_step(proj_stmt) == SQLITE_ROW {
				project_name := string(cstring(sqlite3_column_text(proj_stmt, 0)))
				frame_id := generate_frame_id(project_name, start_time)

				// Update the entry
				update_sql := "UPDATE time_entries SET frame_id = ? WHERE id = ?"
				update_sql_cstr := strings.clone_to_cstring(update_sql, context.temp_allocator)

				update_stmt: ^Sqlite3_Stmt
				if sqlite3_prepare_v2(db, update_sql_cstr, -1, &update_stmt, nil) == SQLITE_OK {
					frame_id_cstr := strings.clone_to_cstring(frame_id, context.temp_allocator)
					sqlite3_bind_text(update_stmt, 1, frame_id_cstr, -1, nil)
					sqlite3_bind_int64(update_stmt, 2, entry_id)
					sqlite3_step(update_stmt)
					sqlite3_finalize(update_stmt)
				}
			}
			sqlite3_finalize(proj_stmt)
		}
	}
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

	// Generate frame ID
	frame_id := generate_frame_id(project, "")

	// Insert time entry with frame_id
	insert_sql := "INSERT INTO time_entries (project_id, start_time, frame_id) VALUES (?, strftime('%Y-%m-%d %H:%M:%S', 'now'), ?)"
	insert_sql_cstr := strings.clone_to_cstring(insert_sql, context.temp_allocator)

	stmt2: ^Sqlite3_Stmt
	if sqlite3_prepare_v2(db, insert_sql_cstr, -1, &stmt2, nil) != SQLITE_OK {
		fmt.eprintln("Failed to prepare insert statement")
		return false
	}
	defer sqlite3_finalize(stmt2)

	frame_id_cstr := strings.clone_to_cstring(frame_id, context.temp_allocator)
	sqlite3_bind_int64(stmt2, 1, project_id)
	sqlite3_bind_text(stmt2, 2, frame_id_cstr, -1, nil)

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
	update_sql := "UPDATE time_entries SET stop_time = strftime('%Y-%m-%d %H:%M:%S', 'now') WHERE id = ?"
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

ProjectInfo :: struct {
	name:       string,
	total_time: string,
}

TimeEntryInfo :: struct {
	project:    string,
	start_time: string,
	stop_time:  string,
	tags:       string,
}

TagInfo :: struct {
	name:  string,
	count: int,
}

list_projects :: proc(allocator := context.allocator) -> [dynamic]ProjectInfo {
	results := make([dynamic]ProjectInfo, allocator)

	query := "SELECT p.name, COALESCE(SUM(CAST((julianday(COALESCE(te.stop_time, strftime('%Y-%m-%d %H:%M:%S', 'now'))) - julianday(te.start_time)) * 24 * 60 * 60 AS INTEGER)), 0) as seconds FROM projects p LEFT JOIN time_entries te ON p.id = te.project_id GROUP BY p.id, p.name ORDER BY p.name"
	query_cstr := strings.clone_to_cstring(query, context.temp_allocator)

	stmt: ^Sqlite3_Stmt
	if sqlite3_prepare_v2(db, query_cstr, -1, &stmt, nil) != SQLITE_OK {
		return results
	}
	defer sqlite3_finalize(stmt)

	for sqlite3_step(stmt) == SQLITE_ROW {
		name := string(cstring(sqlite3_column_text(stmt, 0)))
		seconds := sqlite3_column_int64(stmt, 1)

		hours := seconds / 3600
		mins := (seconds % 3600) / 60
		secs := seconds % 60
		time_str := fmt.aprintf("%d:%02d:%02d", hours, mins, secs, allocator = allocator)

		append(&results, ProjectInfo{name = strings.clone(name, allocator), total_time = time_str})
	}

	return results
}

list_time_entries :: proc(
	from_sql: string = "",
	to_sql: string = "",
	allocator := context.allocator,
) -> [dynamic]TimeEntryInfo {
	results := make([dynamic]TimeEntryInfo, allocator)

	base := "SELECT p.name, te.start_time, COALESCE(te.stop_time, ''), GROUP_CONCAT(t.name, ',') FROM time_entries te JOIN projects p ON te.project_id = p.id LEFT JOIN time_entry_tags tet ON te.id = tet.time_entry_id LEFT JOIN tags t ON tet.tag_id = t.id"
	query: string
	if len(from_sql) > 0 && len(to_sql) > 0 {
		query = fmt.tprintf(
			"%s WHERE te.start_time >= '%s' AND te.start_time <= '%s' GROUP BY te.id ORDER BY te.start_time DESC",
			base,
			from_sql,
			to_sql,
		)
	} else {
		query = fmt.tprintf("%s GROUP BY te.id ORDER BY te.start_time DESC", base)
	}
	query_cstr := strings.clone_to_cstring(query, context.temp_allocator)

	stmt: ^Sqlite3_Stmt
	if sqlite3_prepare_v2(db, query_cstr, -1, &stmt, nil) != SQLITE_OK {
		return results
	}
	defer sqlite3_finalize(stmt)

	for sqlite3_step(stmt) == SQLITE_ROW {
		project := string(cstring(sqlite3_column_text(stmt, 0)))
		start_time := string(cstring(sqlite3_column_text(stmt, 1)))
		stop_time := string(cstring(sqlite3_column_text(stmt, 2)))
		tags_ptr := sqlite3_column_text(stmt, 3)
		tags := ""
		if tags_ptr != nil {
			tags = string(cstring(tags_ptr))
		}

		append(
			&results,
			TimeEntryInfo {
				project = strings.clone(project, allocator),
				start_time = strings.clone(start_time, allocator),
				stop_time = strings.clone(stop_time, allocator),
				tags = strings.clone(tags, allocator),
			},
		)
	}

	return results
}

list_tags :: proc(allocator := context.allocator) -> [dynamic]TagInfo {
	results := make([dynamic]TagInfo, allocator)

	query := "SELECT t.name, COUNT(tet.time_entry_id) as count FROM tags t LEFT JOIN time_entry_tags tet ON t.id = tet.tag_id GROUP BY t.id, t.name ORDER BY count DESC, t.name"
	query_cstr := strings.clone_to_cstring(query, context.temp_allocator)

	stmt: ^Sqlite3_Stmt
	if sqlite3_prepare_v2(db, query_cstr, -1, &stmt, nil) != SQLITE_OK {
		return results
	}
	defer sqlite3_finalize(stmt)

	for sqlite3_step(stmt) == SQLITE_ROW {
		name := string(cstring(sqlite3_column_text(stmt, 0)))
		count := int(sqlite3_column_int64(stmt, 1))

		append(&results, TagInfo{name = strings.clone(name, allocator), count = count})
	}

	return results
}

add_time_entry :: proc(
	project: string,
	start_time: string,
	stop_time: string,
	tags: []string,
) -> bool {
	project_id, ok := get_or_create_project(project)
	if !ok {
		fmt.eprintln("Failed to get/create project")
		return false
	}

	// Generate frame ID
	frame_id := generate_frame_id(project, start_time)

	insert_sql := "INSERT INTO time_entries (project_id, start_time, stop_time, frame_id) VALUES (?, ?, ?, ?)"
	insert_sql_cstr := strings.clone_to_cstring(insert_sql, context.temp_allocator)

	stmt: ^Sqlite3_Stmt
	if sqlite3_prepare_v2(db, insert_sql_cstr, -1, &stmt, nil) != SQLITE_OK {
		fmt.eprintln("Failed to prepare insert statement")
		return false
	}
	defer sqlite3_finalize(stmt)

	start_cstr := strings.clone_to_cstring(start_time, context.temp_allocator)
	stop_cstr := strings.clone_to_cstring(stop_time, context.temp_allocator)
	frame_id_cstr := strings.clone_to_cstring(frame_id, context.temp_allocator)

	sqlite3_bind_int64(stmt, 1, project_id)
	sqlite3_bind_text(stmt, 2, start_cstr, -1, nil)
	sqlite3_bind_text(stmt, 3, stop_cstr, -1, nil)
	sqlite3_bind_text(stmt, 4, frame_id_cstr, -1, nil)

	if sqlite3_step(stmt) != SQLITE_DONE {
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


// Get time entry by frame ID
get_entry_by_frame_id :: proc(
	frame_id: string,
	allocator := context.allocator,
) -> (
	entry: TimeEntryInfo,
	ok: bool,
) {
	query := "SELECT p.name, te.start_time, COALESCE(te.stop_time, ''), GROUP_CONCAT(t.name, ',') FROM time_entries te JOIN projects p ON te.project_id = p.id LEFT JOIN time_entry_tags tet ON te.id = tet.time_entry_id LEFT JOIN tags t ON tet.tag_id = t.id WHERE te.frame_id = ? GROUP BY te.id"
	query_cstr := strings.clone_to_cstring(query, context.temp_allocator)

	stmt: ^Sqlite3_Stmt
	if sqlite3_prepare_v2(db, query_cstr, -1, &stmt, nil) != SQLITE_OK {
		return {}, false
	}
	defer sqlite3_finalize(stmt)

	frame_id_cstr := strings.clone_to_cstring(frame_id, context.temp_allocator)
	sqlite3_bind_text(stmt, 1, frame_id_cstr, -1, nil)

	if sqlite3_step(stmt) == SQLITE_ROW {
		project := string(cstring(sqlite3_column_text(stmt, 0)))
		start_time := string(cstring(sqlite3_column_text(stmt, 1)))
		stop_time := string(cstring(sqlite3_column_text(stmt, 2)))
		tags_ptr := sqlite3_column_text(stmt, 3)
		tags := ""
		if tags_ptr != nil {
			tags = string(cstring(tags_ptr))
		}

		return TimeEntryInfo {
				project = strings.clone(project, allocator),
				start_time = strings.clone(start_time, allocator),
				stop_time = strings.clone(stop_time, allocator),
				tags = strings.clone(tags, allocator),
			},
			true
	}

	return {}, false
}


// Get currently running time entry
get_current_entry :: proc(
	allocator := context.allocator,
) -> (
	entry: TimeEntryInfo,
	frame_id: string,
	ok: bool,
) {
	query := "SELECT te.frame_id, p.name, te.start_time, GROUP_CONCAT(t.name, ',') FROM time_entries te JOIN projects p ON te.project_id = p.id LEFT JOIN time_entry_tags tet ON te.id = tet.time_entry_id LEFT JOIN tags t ON tet.tag_id = t.id WHERE te.stop_time IS NULL GROUP BY te.id"
	query_cstr := strings.clone_to_cstring(query, context.temp_allocator)

	stmt: ^Sqlite3_Stmt
	if sqlite3_prepare_v2(db, query_cstr, -1, &stmt, nil) != SQLITE_OK {
		return {}, "", false
	}
	defer sqlite3_finalize(stmt)

	if sqlite3_step(stmt) == SQLITE_ROW {
		fid := string(cstring(sqlite3_column_text(stmt, 0)))
		project := string(cstring(sqlite3_column_text(stmt, 1)))
		start_time := string(cstring(sqlite3_column_text(stmt, 2)))
		tags_ptr := sqlite3_column_text(stmt, 3)
		tags := ""
		if tags_ptr != nil {
			tags = string(cstring(tags_ptr))
		}

		return TimeEntryInfo {
				project = strings.clone(project, allocator),
				start_time = strings.clone(start_time, allocator),
				stop_time = "",
				tags = strings.clone(tags, allocator),
			},
			strings.clone(fid, allocator),
			true
	}

	return {}, "", false
}


// Cancel (delete) currently running entry
cancel_current_entry :: proc() -> bool {
	// Find running entry
	select_sql := "SELECT id FROM time_entries WHERE stop_time IS NULL"
	select_sql_cstr := strings.clone_to_cstring(select_sql, context.temp_allocator)

	stmt: ^Sqlite3_Stmt
	if sqlite3_prepare_v2(db, select_sql_cstr, -1, &stmt, nil) != SQLITE_OK {
		return false
	}
	defer sqlite3_finalize(stmt)

	if sqlite3_step(stmt) != SQLITE_ROW {
		return false
	}

	entry_id := sqlite3_column_int64(stmt, 0)

	// Delete entry (CASCADE will handle tags)
	delete_sql := "DELETE FROM time_entries WHERE id = ?"
	delete_sql_cstr := strings.clone_to_cstring(delete_sql, context.temp_allocator)

	stmt2: ^Sqlite3_Stmt
	if sqlite3_prepare_v2(db, delete_sql_cstr, -1, &stmt2, nil) != SQLITE_OK {
		return false
	}
	defer sqlite3_finalize(stmt2)

	sqlite3_bind_int64(stmt2, 1, entry_id)

	return sqlite3_step(stmt2) == SQLITE_DONE
}


// List all frame IDs
list_frame_ids :: proc(limit: int = 0, allocator := context.allocator) -> [dynamic]string {
	results := make([dynamic]string, allocator)

	query := "SELECT frame_id FROM time_entries WHERE frame_id IS NOT NULL ORDER BY start_time DESC"
	if limit > 0 {
		query = fmt.tprintf(
			"SELECT frame_id FROM time_entries WHERE frame_id IS NOT NULL ORDER BY start_time DESC LIMIT %d",
			limit,
		)
	}
	query_cstr := strings.clone_to_cstring(query, context.temp_allocator)

	stmt: ^Sqlite3_Stmt
	if sqlite3_prepare_v2(db, query_cstr, -1, &stmt, nil) != SQLITE_OK {
		return results
	}
	defer sqlite3_finalize(stmt)

	for sqlite3_step(stmt) == SQLITE_ROW {
		frame_id := string(cstring(sqlite3_column_text(stmt, 0)))
		append(&results, strings.clone(frame_id, allocator))
	}

	return results
}


// Report data structures
ProjectReport :: struct {
	project:       string,
	total_seconds: i64,
	tag_times:     map[string]i64,
}

// Get report data
get_report_data :: proc(
	from_sql: string = "",
	to_sql: string = "",
	allocator := context.allocator,
) -> [dynamic]ProjectReport {
	results := make([dynamic]ProjectReport, allocator)

	time_filter := ""
	if len(from_sql) > 0 && len(to_sql) > 0 {
		time_filter = fmt.tprintf(
			"AND te.start_time >= '%s' AND te.start_time <= '%s'",
			from_sql,
			to_sql,
		)
	}

	query := fmt.tprintf(
		`
		SELECT p.name,
		       COALESCE(SUM(CAST((julianday(COALESCE(te.stop_time, strftime('%%Y-%%m-%%d %%H:%%M:%%S', 'now'))) - julianday(te.start_time)) * 24 * 60 * 60 AS INTEGER)), 0) as seconds
		FROM projects p
		LEFT JOIN time_entries te ON p.id = te.project_id %s
		GROUP BY p.id, p.name
		ORDER BY p.name
	`,
		time_filter,
	)
	query_cstr := strings.clone_to_cstring(query, context.temp_allocator)

	stmt: ^Sqlite3_Stmt
	if sqlite3_prepare_v2(db, query_cstr, -1, &stmt, nil) != SQLITE_OK {
		return results
	}
	defer sqlite3_finalize(stmt)

	for sqlite3_step(stmt) == SQLITE_ROW {
		project := string(cstring(sqlite3_column_text(stmt, 0)))
		seconds := sqlite3_column_int64(stmt, 1)

		report := ProjectReport {
			project       = strings.clone(project, allocator),
			total_seconds = seconds,
			tag_times     = make(map[string]i64, allocator = allocator),
		}

		// Get tag breakdown for this project (respecting time filter)
		tag_time_filter := ""
		if len(from_sql) > 0 && len(to_sql) > 0 {
			tag_time_filter = fmt.tprintf(
				"AND te.start_time >= '%s' AND te.start_time <= '%s'",
				from_sql,
				to_sql,
			)
		}
		tag_query := fmt.tprintf(
			`
			SELECT t.name,
			       COALESCE(SUM(CAST((julianday(COALESCE(te.stop_time, strftime('%%Y-%%m-%%d %%H:%%M:%%S', 'now'))) - julianday(te.start_time)) * 24 * 60 * 60 AS INTEGER)), 0) as seconds
			FROM time_entries te
			JOIN projects p ON te.project_id = p.id
			JOIN time_entry_tags tet ON te.id = tet.time_entry_id
			JOIN tags t ON tet.tag_id = t.id
			WHERE p.name = ? %s
			GROUP BY t.id, t.name
		`,
			tag_time_filter,
		)
		tag_query_cstr := strings.clone_to_cstring(tag_query, context.temp_allocator)
		project_cstr := strings.clone_to_cstring(project, context.temp_allocator)

		tag_stmt: ^Sqlite3_Stmt
		if sqlite3_prepare_v2(db, tag_query_cstr, -1, &tag_stmt, nil) == SQLITE_OK {
			sqlite3_bind_text(tag_stmt, 1, project_cstr, -1, nil)

			for sqlite3_step(tag_stmt) == SQLITE_ROW {
				tag := string(cstring(sqlite3_column_text(tag_stmt, 0)))
				tag_seconds := sqlite3_column_int64(tag_stmt, 1)
				report.tag_times[strings.clone(tag, allocator)] = tag_seconds
			}
			sqlite3_finalize(tag_stmt)
		}

		append(&results, report)
	}

	return results
}

// Rename a project or tag across all entries
rename_project :: proc(old_name: string, new_name: string) -> bool {
	upd := "UPDATE projects SET name = ? WHERE name = ?"
	upd_cstr := strings.clone_to_cstring(upd, context.temp_allocator)
	stmt: ^Sqlite3_Stmt
	if sqlite3_prepare_v2(db, upd_cstr, -1, &stmt, nil) != SQLITE_OK {
		return false
	}
	defer sqlite3_finalize(stmt)
	new_cstr := strings.clone_to_cstring(new_name, context.temp_allocator)
	old_cstr := strings.clone_to_cstring(old_name, context.temp_allocator)
	sqlite3_bind_text(stmt, 1, new_cstr, -1, nil)
	sqlite3_bind_text(stmt, 2, old_cstr, -1, nil)
	if sqlite3_step(stmt) != SQLITE_DONE {
		return false
	}
	return sqlite3_changes(db) > 0
}

rename_tag :: proc(old_name: string, new_name: string) -> bool {
	upd := "UPDATE tags SET name = ? WHERE name = ?"
	upd_cstr := strings.clone_to_cstring(upd, context.temp_allocator)
	stmt: ^Sqlite3_Stmt
	if sqlite3_prepare_v2(db, upd_cstr, -1, &stmt, nil) != SQLITE_OK {
		return false
	}
	defer sqlite3_finalize(stmt)
	new_cstr := strings.clone_to_cstring(new_name, context.temp_allocator)
	old_cstr := strings.clone_to_cstring(old_name, context.temp_allocator)
	sqlite3_bind_text(stmt, 1, new_cstr, -1, nil)
	sqlite3_bind_text(stmt, 2, old_cstr, -1, nil)
	if sqlite3_step(stmt) != SQLITE_DONE {
		return false
	}
	return sqlite3_changes(db) > 0
}

// Update start_time and/or stop_time of an entry by frame_id
edit_entry_times :: proc(frame_id: string, new_start: string, new_stop: string) -> bool {
	if len(new_start) == 0 && len(new_stop) == 0 {
		return false
	}

	query: string
	if len(new_start) > 0 && len(new_stop) > 0 {
		query = fmt.tprintf(
			"UPDATE time_entries SET start_time = '%s', stop_time = '%s' WHERE frame_id = '%s'",
			new_start,
			new_stop,
			frame_id,
		)
	} else if len(new_start) > 0 {
		query = fmt.tprintf(
			"UPDATE time_entries SET start_time = '%s' WHERE frame_id = '%s'",
			new_start,
			frame_id,
		)
	} else {
		query = fmt.tprintf(
			"UPDATE time_entries SET stop_time = '%s' WHERE frame_id = '%s'",
			new_stop,
			frame_id,
		)
	}

	query_cstr := strings.clone_to_cstring(query, context.temp_allocator)
	stmt: ^Sqlite3_Stmt
	if sqlite3_prepare_v2(db, query_cstr, -1, &stmt, nil) != SQLITE_OK {
		return false
	}
	defer sqlite3_finalize(stmt)
	if sqlite3_step(stmt) != SQLITE_DONE {
		return false
	}
	return sqlite3_changes(db) > 0
}

format_duration :: proc(seconds: i64) -> string {
	hours := seconds / 3600
	mins := (seconds % 3600) / 60
	return fmt.tprintf("%dh %02dm", hours, mins)
}

// Get the most recently stopped entry (for restart)
get_last_entry :: proc(
	allocator := context.allocator,
) -> (
	entry: TimeEntryInfo,
	frame_id: string,
	ok: bool,
) {
	query := "SELECT te.frame_id, p.name, te.start_time, GROUP_CONCAT(t.name, ',') FROM time_entries te JOIN projects p ON te.project_id = p.id LEFT JOIN time_entry_tags tet ON te.id = tet.time_entry_id LEFT JOIN tags t ON tet.tag_id = t.id WHERE te.stop_time IS NOT NULL GROUP BY te.id ORDER BY te.stop_time DESC LIMIT 1"
	query_cstr := strings.clone_to_cstring(query, context.temp_allocator)

	stmt: ^Sqlite3_Stmt
	if sqlite3_prepare_v2(db, query_cstr, -1, &stmt, nil) != SQLITE_OK {
		return {}, "", false
	}
	defer sqlite3_finalize(stmt)

	if sqlite3_step(stmt) == SQLITE_ROW {
		fid := string(cstring(sqlite3_column_text(stmt, 0)))
		project := string(cstring(sqlite3_column_text(stmt, 1)))
		start_time := string(cstring(sqlite3_column_text(stmt, 2)))
		tags_ptr := sqlite3_column_text(stmt, 3)
		tags := ""
		if tags_ptr != nil {
			tags = string(cstring(tags_ptr))
		}
		return TimeEntryInfo {
				project = strings.clone(project, allocator),
				start_time = strings.clone(start_time, allocator),
				stop_time = "",
				tags = strings.clone(tags, allocator),
			},
			strings.clone(fid, allocator),
			true
	}
	return {}, "", false
}

// Delete a time entry by frame ID; returns false if not found
remove_entry_by_frame_id :: proc(frame_id: string) -> bool {
	query := "DELETE FROM time_entries WHERE frame_id = ?"
	query_cstr := strings.clone_to_cstring(query, context.temp_allocator)

	stmt: ^Sqlite3_Stmt
	if sqlite3_prepare_v2(db, query_cstr, -1, &stmt, nil) != SQLITE_OK {
		return false
	}
	defer sqlite3_finalize(stmt)

	fid_cstr := strings.clone_to_cstring(frame_id, context.temp_allocator)
	sqlite3_bind_text(stmt, 1, fid_cstr, -1, nil)

	if sqlite3_step(stmt) != SQLITE_DONE {
		return false
	}
	return sqlite3_changes(db) > 0
}

// Change the project and/or tags of an entry identified by frame_id.
// Pass empty string for project to keep existing. Pass nil for tags to keep existing.
change_entry :: proc(
	frame_id: string,
	new_project: string,
	new_tags: []string,
	has_tags: bool,
) -> bool {
	// Resolve entry id
	id_query := "SELECT id FROM time_entries WHERE frame_id = ?"
	id_query_cstr := strings.clone_to_cstring(id_query, context.temp_allocator)
	id_stmt: ^Sqlite3_Stmt
	if sqlite3_prepare_v2(db, id_query_cstr, -1, &id_stmt, nil) != SQLITE_OK {
		return false
	}
	defer sqlite3_finalize(id_stmt)
	fid_cstr := strings.clone_to_cstring(frame_id, context.temp_allocator)
	sqlite3_bind_text(id_stmt, 1, fid_cstr, -1, nil)
	if sqlite3_step(id_stmt) != SQLITE_ROW {
		return false
	}
	entry_id := sqlite3_column_int64(id_stmt, 0)

	// Update project if provided
	if len(new_project) > 0 {
		proj_id, ok := get_or_create_project(new_project)
		if !ok {
			return false
		}
		upd := "UPDATE time_entries SET project_id = ? WHERE id = ?"
		upd_cstr := strings.clone_to_cstring(upd, context.temp_allocator)
		upd_stmt: ^Sqlite3_Stmt
		if sqlite3_prepare_v2(db, upd_cstr, -1, &upd_stmt, nil) != SQLITE_OK {
			return false
		}
		defer sqlite3_finalize(upd_stmt)
		sqlite3_bind_int64(upd_stmt, 1, proj_id)
		sqlite3_bind_int64(upd_stmt, 2, entry_id)
		if sqlite3_step(upd_stmt) != SQLITE_DONE {
			return false
		}
	}

	// Replace tags if provided
	if has_tags {
		del := "DELETE FROM time_entry_tags WHERE time_entry_id = ?"
		del_cstr := strings.clone_to_cstring(del, context.temp_allocator)
		del_stmt: ^Sqlite3_Stmt
		if sqlite3_prepare_v2(db, del_cstr, -1, &del_stmt, nil) != SQLITE_OK {
			return false
		}
		defer sqlite3_finalize(del_stmt)
		sqlite3_bind_int64(del_stmt, 1, entry_id)
		sqlite3_step(del_stmt)

		for tag in new_tags {
			tag_id, tag_ok := get_or_create_tag(tag)
			if !tag_ok do continue
			ins := "INSERT OR IGNORE INTO time_entry_tags (time_entry_id, tag_id) VALUES (?, ?)"
			ins_cstr := strings.clone_to_cstring(ins, context.temp_allocator)
			ins_stmt: ^Sqlite3_Stmt
			if sqlite3_prepare_v2(db, ins_cstr, -1, &ins_stmt, nil) == SQLITE_OK {
				sqlite3_bind_int64(ins_stmt, 1, entry_id)
				sqlite3_bind_int64(ins_stmt, 2, tag_id)
				sqlite3_step(ins_stmt)
				sqlite3_finalize(ins_stmt)
			}
		}
	}

	return true
}

// DailyAggregate holds total seconds per project for one day
DailyAggregate :: struct {
	date:    string,
	project: string,
	seconds: i64,
}

// Get daily aggregated time per project
get_aggregate_data :: proc(
	from_sql: string = "",
	to_sql: string = "",
	allocator := context.allocator,
) -> [dynamic]DailyAggregate {
	results := make([dynamic]DailyAggregate, allocator)

	time_filter := ""
	if len(from_sql) > 0 && len(to_sql) > 0 {
		time_filter = fmt.tprintf(
			"WHERE te.start_time >= '%s' AND te.start_time <= '%s'",
			from_sql,
			to_sql,
		)
	}

	query := fmt.tprintf(
		`
		SELECT date(te.start_time) as day, p.name,
		       CAST(SUM((julianday(COALESCE(te.stop_time, strftime('%%Y-%%m-%%d %%H:%%M:%%S','now'))) - julianday(te.start_time)) * 86400) AS INTEGER)
		FROM time_entries te
		JOIN projects p ON te.project_id = p.id
		%s
		GROUP BY day, p.id
		ORDER BY day DESC, p.name
	`,
		time_filter,
	)
	query_cstr := strings.clone_to_cstring(query, context.temp_allocator)
	stmt: ^Sqlite3_Stmt
	if sqlite3_prepare_v2(db, query_cstr, -1, &stmt, nil) != SQLITE_OK {
		return results
	}
	defer sqlite3_finalize(stmt)

	for sqlite3_step(stmt) == SQLITE_ROW {
		date := string(cstring(sqlite3_column_text(stmt, 0)))
		project := string(cstring(sqlite3_column_text(stmt, 1)))
		secs := sqlite3_column_int64(stmt, 2)
		append(
			&results,
			DailyAggregate {
				date = strings.clone(date, allocator),
				project = strings.clone(project, allocator),
				seconds = secs,
			},
		)
	}
	return results
}
