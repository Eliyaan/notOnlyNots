import os
import time

struct App {
mut:
	g    bool = true
}

fn main() {
	mut app := &App{}
	spawn app.computation_loop()
	app.placement()
	for app.g {}
}

fn (mut app App) computation_loop() {
	for app.g {
		mut file := os.open_file('test', 'w') or { continue }
		file.write_raw_at(i64(0), 0) or {
			println('${@LOCATION}: ${err}')
			app.g = false
		}
		// gc_disable() // Workaround
		time.sleep(0)
		// gc_enable()
	}
}

fn (mut app App) placement() {
	mut m := []Chunk{}
	yl: for y in 0 .. 100 {
		if y > 99 {
			continue yl
		}
		m << Chunk{}
	}
}

struct Chunk {
	id_map [1000]u64
}
