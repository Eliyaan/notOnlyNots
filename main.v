import os
import time

struct App {
mut:
	map  []Chunk
	todo TodoInfo
	g    bool = true
}

struct TodoInfo {
	name string
}

fn main() {
	mut app := &App{}
	name := 'test'
	spawn app.computation_loop()
	app.placement()
	app.todo = TodoInfo{name}
	for app.g {}
}

fn (mut app App) computation_loop() {
	for app.g {
		if app.todo != TodoInfo{} {
			mut file := os.open_file(app.todo.name, 'w') or { return }
			file.write_raw_at(i64(0), 0) or {
				println('${@LOCATION}: ${err}')
				app.g = false
			}
		}
		// gc_disable() // Workaround
		time.sleep(0)
		// gc_enable()
	}
}

fn (mut app App) placement() {
	x_start := u32(0)
	y_start := x_start
	x_end := x_start + 100
	y_end := x_end
	for x in x_start .. x_end {
		yl: for y in y_start .. y_end {
			for _, chunk in app.map {
				if x > chunk.x {
					continue yl
				}
			}
			app.map << Chunk{
				x: x
				y: y
			}
		}
	}
}

struct Chunk {
	x      u32
	y      u32
	id_map [1000]u64
}
