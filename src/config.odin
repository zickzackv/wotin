package main

import "core:os"
import "core:path/filepath"
import "core:strings"

// Configuration constants
WOTIN_VERSION :: "0.1.1"
CONFIG_DIR_NAME :: ".wotin"
CONFIG_FILE_NAME :: "config.json"
DATA_FILE_NAME :: "frames.json"

// Get the configuration directory path
get_config_dir :: proc() -> string {
	// Get user home directory
	home_dir := os.get_env("HOME")
	when ODIN_OS == .Windows {
		home_dir = os.get_env("USERPROFILE")
	}

	return filepath.join({home_dir, CONFIG_DIR_NAME})
}

// Get the configuration file path
get_config_file :: proc() -> string {
	config_dir := get_config_dir()
	return filepath.join({config_dir, CONFIG_FILE_NAME})
}

// Get the data file path
get_data_file :: proc() -> string {
	config_dir := get_config_dir()
	return filepath.join({config_dir, DATA_FILE_NAME})
}

// get_wotin_config_path returns ~/.config/wotin/config (respects XDG_CONFIG_HOME)
get_wotin_config_path :: proc() -> string {
	xdg := os.get_env("XDG_CONFIG_HOME")
	base := xdg if len(xdg) > 0 else filepath.join({os.get_env("HOME"), ".config"})
	return filepath.join({base, "wotin", "config"})
}

// load_config reads KEY=VALUE pairs from the config file and applies them.
// Supported keys: db_path, no_color
// Priority: CLI flag > WOTIN_DB env > config file > default
load_config :: proc() {
	path := get_wotin_config_path()
	data, ok := os.read_entire_file(path, context.temp_allocator)
	if !ok do return

	content := string(data)
	for line in strings.split_lines_iterator(&content) {
		line := strings.trim_space(line)
		if len(line) == 0 || line[0] == '#' do continue
		eq := strings.index(line, "=")
		if eq < 0 do continue
		key := strings.trim_space(line[:eq])
		val := strings.trim_space(line[eq + 1:])
		switch key {
		case "db_path":
			// Only apply if WOTIN_DB not already set
			if len(os.get_env("WOTIN_DB")) == 0 {
				os.set_env("WOTIN_DB", val)
			}
		case "no_color":
			if val == "1" || val == "true" {
				os.set_env("NO_COLOR", "1")
			}
		}
	}
}

