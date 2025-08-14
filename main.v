import os
import time

struct App {
mut:
	map  []Chunk
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
	for _ in 0 .. 100 {
		yl: for y in 0 .. 100 {
			for _, _ in app.map {
				if y > 1 {
					continue yl
				}
			}
			app.map << Chunk{}
		}
	}
}

struct Chunk {
	x      u32
	y      u32
	id_map [1000]u64
}
