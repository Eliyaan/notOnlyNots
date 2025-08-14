import os
import time

struct App {
mut:
	map          []Chunk
	todo         []TodoInfo
}

struct TodoInfo {
	name string
}

fn main() {
	mut app := &App{}
	name := 'test'
	spawn app.computation_loop()
	app.placement()
	app.todo << TodoInfo{name}
	for {}
}

fn (mut app App) computation_loop() {
	for {
		for _, todo in app.todo {
			mut file := os.open_file(todo.name, 'w') or { return }
			mut offset := u64(0)
			file.write_raw_at(i64(3), offset) or { println('${@LOCATION}: ${err}') }
		}
		//gc_disable() // Workaround
		time.sleep(0)
		//gc_enable()
	}
}

fn (mut app App) placement() {
	x_start := u32(2)
	y_start := x_start
	x_end := x_start + 100
	y_end := x_end
	for x in x_start .. x_end + 1 {
		yl: for y in y_start .. y_end + 1 {
			for _, chunk in app.map {
					if x < chunk.x + 10 && y < chunk.y + 10 {
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
	id_map [60]u64 // higher is more probable to reproduce
}
