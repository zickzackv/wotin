package main

import "core:c"

when ODIN_OS == .Linux {
    foreign import sqlite3 "system:sqlite3"
}

Sqlite3 :: struct {}
Sqlite3_Stmt :: struct {}

SQLITE_OK :: 0
SQLITE_ROW :: 100
SQLITE_DONE :: 101

@(default_calling_convention="c")
foreign sqlite3 {
    sqlite3_open :: proc(filename: cstring, ppDb: ^^Sqlite3) -> c.int ---
    sqlite3_close :: proc(db: ^Sqlite3) -> c.int ---
    sqlite3_exec :: proc(db: ^Sqlite3, sql: cstring, callback: rawptr, arg: rawptr, errmsg: ^cstring) -> c.int ---
    sqlite3_prepare_v2 :: proc(db: ^Sqlite3, sql: cstring, nByte: c.int, ppStmt: ^^Sqlite3_Stmt, pzTail: ^cstring) -> c.int ---
    sqlite3_step :: proc(stmt: ^Sqlite3_Stmt) -> c.int ---
    sqlite3_finalize :: proc(stmt: ^Sqlite3_Stmt) -> c.int ---
    sqlite3_bind_text :: proc(stmt: ^Sqlite3_Stmt, idx: c.int, text: cstring, n: c.int, destructor: rawptr) -> c.int ---
    sqlite3_bind_int64 :: proc(stmt: ^Sqlite3_Stmt, idx: c.int, value: i64) -> c.int ---
    sqlite3_column_int64 :: proc(stmt: ^Sqlite3_Stmt, iCol: c.int) -> i64 ---
    sqlite3_column_text :: proc(stmt: ^Sqlite3_Stmt, iCol: c.int) -> cstring ---
    sqlite3_errmsg :: proc(db: ^Sqlite3) -> cstring ---
    sqlite3_last_insert_rowid :: proc(db: ^Sqlite3) -> i64 ---
}
