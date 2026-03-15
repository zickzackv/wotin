package main

import "core:time"
import "core:fmt"

TimeRange :: struct {
	from: time.Time,
	to: time.Time,
}

// Resolve time shortcuts like --today, --yesterday, --week, etc.
resolve_time_range :: proc(flags: map[string]string) -> (range: TimeRange, ok: bool) {
	now := time.now()
	
	DAY :: 24 * time.Hour
	
	// Check for shortcuts
	if _, has_today := flags["today"]; has_today {
		start_of_day := time.Time{
			_nsec = (now._nsec / i64(DAY)) * i64(DAY),
		}
		end_of_day := time.Time{
			_nsec = start_of_day._nsec + i64(DAY) - 1,
		}
		return TimeRange{from = start_of_day, to = end_of_day}, true
	}
	
	if _, has_yesterday := flags["yesterday"]; has_yesterday {
		yesterday := time.Time{_nsec = now._nsec - i64(DAY)}
		start_of_day := time.Time{
			_nsec = (yesterday._nsec / i64(DAY)) * i64(DAY),
		}
		end_of_day := time.Time{
			_nsec = start_of_day._nsec + i64(DAY) - 1,
		}
		return TimeRange{from = start_of_day, to = end_of_day}, true
	}
	
	if _, has_week := flags["week"]; has_week {
		// Get start of week (Monday)
		// time.Weekday: Sunday=0, Monday=1, ..., Saturday=6
		weekday := int(time.weekday(now))
		days_since_monday := (weekday + 6) % 7  // Convert to Monday=0
		
		start_of_week := time.Time{
			_nsec = now._nsec - i64(time.Duration(days_since_monday) * DAY),
		}
		start_of_week._nsec = (start_of_week._nsec / i64(DAY)) * i64(DAY)
		
		end_of_week := time.Time{
			_nsec = start_of_week._nsec + i64(7 * DAY) - 1,
		}
		return TimeRange{from = start_of_week, to = end_of_week}, true
	}
	
	if _, has_month := flags["month"]; has_month {
		year, month, _ := time.date(now)
		
		// Start of month
		start_of_month, _ := time.datetime_to_time(year, month, 1, 0, 0, 0)
		
		// End of month (start of next month - 1 nanosecond)
		next_month := int(month) + 1
		next_year := year
		if next_month > 12 {
			next_month = 1
			next_year += 1
		}
		end_of_month, _ := time.datetime_to_time(next_year, time.Month(next_month), 1, 0, 0, 0)
		end_of_month._nsec -= 1
		
		return TimeRange{from = start_of_month, to = end_of_month}, true
	}
	
	if _, has_year := flags["year"]; has_year {
		year, _, _ := time.date(now)
		
		// Start of year
		start_of_year, _ := time.datetime_to_time(year, 1, 1, 0, 0, 0)
		
		// End of year
		end_of_year, _ := time.datetime_to_time(year + 1, 1, 1, 0, 0, 0)
		end_of_year._nsec -= 1
		
		return TimeRange{from = start_of_year, to = end_of_year}, true
	}
	
	// Check for --from and --to
	from_str, has_from := flags["from"]
	to_str, has_to := flags["to"]
	
	if has_from && has_to {
		// Parse custom date range
		from_time, from_ok := parse_datetime(from_str)
		to_time, to_ok := parse_datetime(to_str)
		
		if from_ok && to_ok {
			// Convert string times to time.Time (simplified - would need proper parsing)
			// For now, return a placeholder
			return TimeRange{from = now, to = now}, true
		}
	}
	
	// Default: last 7 days
	seven_days_ago := time.Time{
		_nsec = now._nsec - i64(7 * DAY),
	}
	return TimeRange{from = seven_days_ago, to = now}, true
}

// Format time range for display
format_time_range :: proc(range: TimeRange) -> string {
	from_str := fmt.tprintf("%v", range.from)
	to_str := fmt.tprintf("%v", range.to)
	return fmt.tprintf("%s to %s", from_str, to_str)
}
