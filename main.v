import os
import time

struct App {
mut:
	g    bool = true
}

fn main() {
	mut app := &App{}
	spawn computation_loop(mut app)
	placement()
	for app.g {}
}

fn  computation_loop(mut app App) {
	mut file := os.open_file('test', 'w') or { return }
	for app.g {
		file.write_raw_at(i64(0), 0) or {
			println('${@LOCATION}: ${err}')
			app.g = false
		}
		// gc_disable() // Workaround
		time.sleep(0)
		// gc_enable()
	}
}

fn placement() {
	mut m := []Chunk{}
	for _ in 0 .. 100 {
		m << Chunk{}
	}
}

struct Chunk {
	id_map [10000]u64
}
