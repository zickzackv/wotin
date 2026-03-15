package main

import "core:fmt"
import "core:strconv"
import "core:strings"
import "core:time"

parse_datetime :: proc(input: string) -> (string, bool) {
	trimmed := strings.trim_space(input)

	// Try "HH:MM" format (today's date)
	if len(trimmed) == 5 && trimmed[2] == ':' {
		return parse_time_only(trimmed)
	}

	// Try "YYYY-MM-DD HH:MM" or "YYYY-MM-DDTHH:MM" format
	if len(trimmed) >= 16 {
		// Check if it contains T separator and convert to space
		datetime_str := trimmed
		if strings.contains(trimmed, "T") {
			datetime_str, _ = strings.replace_all(trimmed, "T", " ")
		}
		return parse_full_datetime(datetime_str)
	}

	return "", false
}

parse_time_only :: proc(time_str: string) -> (string, bool) {
	parts := strings.split(time_str, ":", context.temp_allocator)
	if len(parts) != 2 {
		return "", false
	}

	hour, hour_ok := strconv.parse_int(strings.trim_space(parts[0]))
	minute, minute_ok := strconv.parse_int(strings.trim_space(parts[1]))

	if !hour_ok || !minute_ok || hour < 0 || hour > 23 || minute < 0 || minute > 59 {
		return "", false
	}

	// Get today's date
	now := time.now()
	year, month, day := time.date(now)

	result := fmt.aprintf(
		"%04d-%02d-%02d %02d:%02d:00",
		year,
		int(month),
		day,
		hour,
		minute,
		allocator = context.temp_allocator,
	)

	return result, true
}

parse_full_datetime :: proc(datetime_str: string) -> (string, bool) {
	parts := strings.split(datetime_str, " ", context.temp_allocator)
	if len(parts) != 2 {
		return "", false
	}

	date_part := strings.trim_space(parts[0])
	time_part := strings.trim_space(parts[1])

	// Validate date format YYYY-MM-DD
	date_parts := strings.split(date_part, "-", context.temp_allocator)
	if len(date_parts) != 3 {
		return "", false
	}

	year, year_ok := strconv.parse_int(strings.trim_space(date_parts[0]))
	month, month_ok := strconv.parse_int(strings.trim_space(date_parts[1]))
	day, day_ok := strconv.parse_int(strings.trim_space(date_parts[2]))

	if !year_ok || !month_ok || !day_ok {
		return "", false
	}

	if month < 1 || month > 12 || day < 1 || day > 31 {
		return "", false
	}

	// Validate time format HH:MM or HH:MM:SS
	time_parts := strings.split(time_part, ":", context.temp_allocator)
	if len(time_parts) < 2 || len(time_parts) > 3 {
		return "", false
	}

	hour, hour_ok := strconv.parse_int(strings.trim_space(time_parts[0]))
	minute, minute_ok := strconv.parse_int(strings.trim_space(time_parts[1]))
	second := 0

	if len(time_parts) == 3 {
		second_ok: bool
		second, second_ok = strconv.parse_int(strings.trim_space(time_parts[2]))
		if !second_ok || second < 0 || second > 59 {
			return "", false
		}
	}

	if !hour_ok || !minute_ok || hour < 0 || hour > 23 || minute < 0 || minute > 59 {
		return "", false
	}

	result := fmt.aprintf(
		"%04d-%02d-%02d %02d:%02d:%02d",
		year,
		month,
		day,
		hour,
		minute,
		second,
		allocator = context.temp_allocator,
	)

	return result, true
}

pad_zero :: proc(num: int) -> string {
	return fmt.aprintf("%02d", num, allocator = context.temp_allocator)
}
