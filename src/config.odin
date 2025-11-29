package main

import "core:os"
import "core:path/filepath"

// Configuration constants
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
