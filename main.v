import os
import time

const chunk_size = 10

struct App {
mut:
	text_input      string
	map             []Chunk
	map_name        string
	comp_running    bool
	nb_updates      int = 5
	avg_update_time f64
	todo            []TodoInfo
}

fn (mut app App) create_game() {
	app.map_name = app.text_input
	app.comp_running = true
	spawn app.computation_loop()
}


struct TodoInfo {
	name  string
}

fn (mut app App) computation_loop() {
	mut cycle_end := i64(0)
	mut now := i64(0)
	for app.comp_running {
		for i, todo in app.todo {
						mut file := os.open_file(todo.name, 'w') or { return }
						mut offset := u64(0)
						file.write_raw_at(i64(3), offset) or { println('${@LOCATION}: ${err}') }
						app.comp_running = false
		}
			time.sleep((cycle_end - now) * time.nanosecond)
	}
}

fn (mut app App) placement(x_start u32, y_start u32, x_end u32, y_end u32) {
			for x in x_start .. x_end + 1 {
				yl: for y in y_start .. y_end + 1 {
					for i, chunk in app.map {
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
