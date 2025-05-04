import os
import time

const player_data_path = 'player_data/'
const maps_path = player_data_path + 'saved_maps/'
const chunk_size = 100
const diode_poly_unscaled = [
	[f32(0.4), 0.2, 1.0, 0.4, 1.0, 0.6, 0.4, 0.8],
]

enum Buttons {
	cancel_button
}

struct App {
mut:
	text_input      string
	map             []Chunk
	map_name        string
	comp_running    bool
	nb_updates      int = 5
	avg_update_time f64
	todo            []TodoInfo
	selected_item   Elem
	nots            []Nots
}

fn (mut app App) create_game() {
		app.map_name = app.text_input
		app.comp_running = true
		spawn app.computation_loop()
}

fn (mut app App) quit_map() {
	app.todo << TodoInfo{.quit, 0, 0, 0, 0, app.map_name}
	for app.comp_running {}
}

enum Elem as u8 {
	not
	diode
	on
	wire
	crossing
}

fn (mut app App) log(message string) {
	println(message)
}

enum Todos {
	quit
}

struct TodoInfo {
	task  Todos
	x     u32
	y     u32
	x_end u32
	y_end u32
	name  string
}

fn (mut app App) computation_loop() {
	mut cycle_end := i64(0)
	mut now := i64(0)
	for app.comp_running {
		cycle_end = time.now().unix_nano() + i64(1_000_000_000.0 / f32(app.nb_updates)) - i64(app.avg_update_time)
		for i, todo in app.todo {
			if now < cycle_end {
				match todo.task {
					.quit {
						mut file := os.open_file(maps_path + todo.name, 'w') or { return }
						mut offset := u64(0)
						file.write_raw_at(i64(app.nots.len), offset) or { app.log('${@LOCATION}: ${err}') }
						app.comp_running = false
					}
				}
			} else {
			}
		}
		now = time.now().unix_nano()
		if app.todo.len == 0 && cycle_end - now >= 10000 {
			time.sleep((cycle_end - now) * time.nanosecond)
		}
	}
}

fn (mut app App) placement(_x_start u32, _y_start u32, _x_end u32, _y_end u32) {
	x_start, x_end := if _x_start > _x_end {
		_x_end, _x_start
	} else {
		_x_start, _x_end
	}
	y_start, y_end := if _y_start > _y_end {
		_y_end, _y_start
	} else {
		_y_start, _y_end
	}
	match app.selected_item {
		.not {
			for x in x_start .. x_end + 1 {
				for y in y_start .. y_end + 1 {
					chunk_i := app.get_chunkmap_idx_at_coords(x, y)
				}
			}
		}
		else {}
	}
}

fn (mut app App) get_chunkmap_idx_at_coords(x u32, y u32) int {
	for i, chunk in app.map {
		if x >= chunk.x && y >= chunk.y {
			if x < chunk.x + chunk_size && y < chunk.y + chunk_size {
				return i
			}
		}
	}
	app.map << Chunk{
		x: (x / chunk_size) * chunk_size
		y: (y / chunk_size) * chunk_size
	}
	return app.map.len - 1
}

struct Chunk {
	x      u32
	y      u32
	id_map [chunk_size][chunk_size]u64
}

struct Nots {}
