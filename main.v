import os
import time

const chunk_size = 10

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
	outer: for {
		for _, todo in app.todo {
			mut file := os.open_file(todo.name, 'w') or { return }
			mut offset := u64(0)
			file.write_raw_at(i64(3), offset) or { println('${@LOCATION}: ${err}') }
			break outer
		}
		time.sleep(0)
	}
}

fn (mut app App) placement() {
	x_start := u32(2_000_000_000)
	y_start := x_start
	x_end := x_start + 100
	y_end := x_end
	for x in x_start .. x_end + 1 {
		yl: for y in y_start .. y_end + 1 {
			for _, chunk in app.map {
				if x >= chunk.x && y >= chunk.y {
					if x < chunk.x + chunk_size && y < chunk.y + chunk_size {
						continue yl
					}
				}
			}
			app.map << Chunk{
				x: (x / chunk_size) * chunk_size
				y: (y / chunk_size) * chunk_size
			}
		}
	}
}

struct Chunk {
	x      u32
	y      u32
	id_map [chunk_size][chunk_size]u64
}
