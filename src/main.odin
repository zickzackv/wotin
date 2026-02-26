package main

import "core:fmt"
import "core:os"
import "core:time"

STATE_FILE :: ".timer_state"
LOG_FILE :: "zeit_log.txt"

main :: proc() {
	args := os.args
	if len(args) < 2 {
		fmt.println("Nutzung: timer <start|stop>")
		return
	}

	// Da handle_start/stop jetzt Fehler zurückgeben, fangen wir sie hier ab
	err: os.Error
	switch args[1] {
	case "start":
		err = handle_start()
	case "stop":
		err = handle_stop()
	case:
		fmt.printf("Unbekannter Befehl: '%s'\n", args[1])
	}

	if err != nil {
		fmt.eprintf("Fehler aufgetreten: %v\n", err)
		os.exit(1)
	}
}

handle_start :: proc() -> os.Error {
	if _, err := os.stat(STATE_FILE); err == nil {
		fmt.println("Warnung: Timer läuft bereits.")
	}

	now := time.now()
	if time_str, ok := time.time_to_rfc3339(now); ok {
		os.write_entire_file_or_err(STATE_FILE, transmute([]u8)time_str) or_return
		fmt.printf("Timer gestartet um: %s\n", time_str)
	} else {
		fmt.println("Fehler: Konnte Zeit nicht nehmen!")
		os.exit(10)
	}

	return nil
}

handle_stop :: proc() -> os.Error {
	data := os.read_entire_file_or_err(STATE_FILE, context.temp_allocator) or_return
	start_str := string(data)

	start_time, consumed := time.rfc3339_to_time_utc(start_str)
	if consumed == 0 {
		fmt.println("Fehler: Zeitstempel ungültig.")
		return .Invalid_File // Oder ein passender os.Error
	}

	stop_time := time.now()
	duration := time.diff(start_time, stop_time)

	log_entry := fmt.tprintf("Start: %v | Stop: %v | Dauer: %v\n", start_time, stop_time, duration)

	fd := os.open(LOG_FILE, os.O_CREATE | os.O_APPEND | os.O_WRONLY, 0644) or_return
	defer os.close(fd)

	os.write_string(fd, log_entry) or_return
	os.remove(STATE_FILE)

	fmt.printf("Timer gestoppt. Dauer: %v\n", duration)
	return nil
}

