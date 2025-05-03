module main

import math
import os
import rand
import time
import gg
import toml

const game_data_path = 'game_data/'
const player_data_path = 'player_data/'
const sprites_path = game_data_path + 'sprites/'
const logs_path = player_data_path + 'logs'
const palette_path = player_data_path + 'palette.toml'
const font_path = game_data_path + 'fonts/0xProtoNerdFontMono-Regular.ttf'
const default_button_color = gg.Color{}
const default_colorchip_color_on = gg.Color{}
const default_colorchip_color_off = gg.Color{}
const default_camera_pos_x = f64(2_000_000_000.0)
const default_camera_pos_y = f64(2_000_000_000.0)
const gates_path = player_data_path + 'saved_gates/'
const maps_path = player_data_path + 'saved_maps/'
const empty_id = u64(0)
const on_bits = u64(0x2000_0000_0000_0000)
const elem_not_bits = u64(0x0000_0000_0000_0000)
const elem_diode_bits = u64(0x4000_0000_0000_0000)
const elem_on_bits = u64(0x8000_0000_0000_0000)
const elem_wire_bits = u64(0xC000_0000_0000_0000)
const elem_crossing_bits = u64(0xFFFF_FFFF_FFFF_FFFF)

const north = u64(0x0)
const south = u64(0x0800_0000_0000_0000)
const west = u64(0x1000_0000_0000_0000)
const east = u64(0x1800_0000_0000_0000)
const rid_mask = u64(0x07FF_FFFF_FFFF_FFFF)
const elem_type_mask = u64(0xC000_0000_0000_0000)
const id_mask = rid_mask | elem_type_mask
const ori_mask = u64(0x1800_0000_0000_0000)
const chunk_size = 100
const diode_poly_unscaled = [
	[f32(0.2), 1.0, 0.4, 0.0, 0.6, 0.0, 0.8, 1.0],
	[f32(0.2), 0.0, 0.8, 0.0, 0.6, 1.0, 0.4, 1.0],
	[f32(1.0), 0.2, 1.0, 0.8, 0.0, 0.6, 0.0, 0.4],
	[f32(0.0), 0.2, 1.0, 0.4, 1.0, 0.6, 0.0, 0.8],
]
const not_rect_unscaled = [
	[f32(0.33), 0.0, 0.33, 0.2],
	[f32(0.33), 0.8, 0.33, 0.2],
	[f32(0.0), 0.33, 0.2, 0.33],
	[f32(0.8), 0.33, 0.2, 0.33],
]
const not_poly_unscaled = [
	[f32(0.2), 1.0, 0.5, 0.0, 0.8, 1.0],
	[f32(0.2), 0.0, 0.8, 0.0, 0.5, 1.0],
	[f32(1.0), 0.2, 1.0, 0.8, 0.0, 0.5],
	[f32(0.0), 0.2, 1.0, 0.5, 0.0, 0.8],
]
const on_poly_unscaled = [
	[f32(0.2), 0.6, 0.4, 0.0, 0.6, 0.0, 0.8, 0.6],
	[f32(0.2), 0.4, 0.8, 0.4, 0.6, 1.0, 0.4, 1.0],
	[f32(0.6), 0.2, 0.6, 0.8, 0.0, 0.6, 0.0, 0.4],
	[f32(0.4), 0.2, 1.0, 0.4, 1.0, 0.6, 0.4, 0.8],
]

enum Buttons {
	cancel_button
	confirm_save_gate
	selection_button
	rotate_copy
	copy_button
	choose_colorchip
	load_gate
	save_gate
	edit_color
	item_nots
	create_color_chip
	add_input
	item_diode
	steal_settings
	item_crossing
	delete_colorchip
	item_on
	item_wire
	speed
	slow
	pause
	paste
	save_map
	keyinput
	hide_colorchips
	quit_map
	selection_delete
	flip_h
	flip_v
}

const selec_buttons = [Buttons.cancel_button, .copy_button, .save_gate, .create_color_chip,
	.selection_delete, .paste]
const no_mode_buttons = [Buttons.cancel_button, .selection_button, .load_gate, .item_nots,
	.item_diode, .item_crossing, .item_on, .item_wire, .speed, .slow, .pause, .paste, .save_map,
	.keyinput, .hide_colorchips, .quit_map]
const save_gate_buttons = [Buttons.cancel_button, .confirm_save_gate]
const paste_buttons = [Buttons.cancel_button, .rotate_copy, .load_gate, .flip_h, .flip_v]
const placement_buttons = [Buttons.cancel_button, .item_nots, .item_diode, .item_crossing, .item_on,
	.item_wire]
const edit_buttons = [Buttons.cancel_button, .choose_colorchip, .edit_color, .add_input,
	.steal_settings, .delete_colorchip]

struct ButtonData {
mut:
	pos u32
	img gg.Image
}

struct Palette {
mut:
	junc            gg.Color = gg.Color{}
	junc_v          gg.Color = gg.Color{}
	junc_h          gg.Color = gg.Color{}
	wire_on         gg.Color = gg.Color{}
	wire_off        gg.Color = gg.Color{}
	on              gg.Color = gg.Color{}
	not             gg.Color = gg.Color{}
	diode           gg.Color = gg.Color{}
	background      gg.Color = gg.Color{}
	place_preview   gg.Color = gg.Color{}
	copy_preview    gg.Color = gg.Color{}
	selection_start gg.Color = gg.Color{}
	selection_end   gg.Color = gg.Color{}
	selection_box   gg.Color = gg.Color{}
	input_preview   gg.Color = gg.Color{}
	selected_ui     gg.Color = gg.Color{}
	ui_bg           gg.Color = gg.Color{}
	grid            gg.Color = gg.Color{}
}

const palette_def = Palette{}

struct ColorChip {
	x u32
	y u32
	w u32
	h u32
mut:
	colors []gg.Color
	inputs [][2]u32
}

const button_map = {
	Buttons.cancel_button: ButtonData{}
	.confirm_save_gate:    ButtonData{}
	.selection_button:     ButtonData{}
	.rotate_copy:          ButtonData{}
	.copy_button:          ButtonData{}
	.choose_colorchip:     ButtonData{}
	.load_gate:            ButtonData{}
	.save_gate:            ButtonData{}
	.edit_color:           ButtonData{}
	.flip_h:               ButtonData{}
	.item_nots:            ButtonData{}
	.create_color_chip:    ButtonData{}
	.add_input:            ButtonData{}
	.flip_v:               ButtonData{}
	.item_diode:           ButtonData{}
	.steal_settings:       ButtonData{}
	.item_crossing:        ButtonData{}
	.delete_colorchip:     ButtonData{}
	.item_on:              ButtonData{}
	.item_wire:            ButtonData{}
	.speed:                ButtonData{}
	.slow:                 ButtonData{}
	.pause:                ButtonData{}
	.paste:                ButtonData{}
	.save_map:             ButtonData{}
	.keyinput:             ButtonData{}
	.hide_colorchips:      ButtonData{}
	.quit_map:             ButtonData{}
	.selection_delete:     ButtonData{}
}

struct App {
mut:
	ctx               &gg.Context = unsafe { nil }
	e                 &gg.Event   = &gg.Event{}
	draw_count        int         = 1
	draw_step         int         = 1000
	tile_size         int         = 50
	text_input        string
	colorchips_hidden bool
	mouse_down        bool
	mouse_map_x       u32
	mouse_map_y       u32
	scroll_pos        f32

	main_menu        bool
	button_solo_x    f32 = 0.0
	button_solo_y    f32 = 0.0
	button_solo_w    f32 = 300.0
	button_solo_h    f32 = 300.0
	button_quit_size f32 = 50.0
	btn_quit_ofst    f32 = 20.0
	solo_img         gg.Image

	solo_menu           bool
	map_names_list      []string
	maps_x_offset       f32 = 50.0
	maps_y_offset       f32 = 50.0
	maps_top_spacing    f32 = 10.0
	maps_h              f32 = 50.0
	maps_w              f32 = 500.0
	button_new_map_x    f32 = 5.0
	button_new_map_y    f32 = 5.0
	button_new_map_size f32 = 40.0
	btn_back_x          f32 = 5.0
	btn_back_y          f32 = 50.0
	btn_back_s          f32 = 40.0
	text_field_x        f32 = 50.0
	text_field_y        f32 = 5.0

	edit_mode                 bool
	editmenu_rgb_y            f32 = 10.0
	editmenu_rgb_h            f32 = 40.0
	editmenu_rgb_w            f32 = 40.0
	editmenu_r_x              f32 = 60.0
	editmenu_g_x              f32 = 110.0
	editmenu_b_x              f32 = 160.0
	editmenu_offset_x         f32 = 160.0
	editmenu_offset_y         f32 = 160.0
	editmenu_nb_color_by_row  int = 10
	editmenu_colorsize        f32 = 50.0
	editmenu_selected_color   int
	editmenu_offset_inputs_x  f32 = 160.0
	editmenu_offset_inputs_y  f32 = 160.0
	editmenu_nb_inputs_by_row int = 10
	editmenu_inputsize        f32 = 50.0
	delete_colorchip_submode  bool
	create_colorchip_submode  bool
	create_colorchip_x        u32 = u32(-1)
	create_colorchip_y        u32 = u32(-1)
	create_colorchip_endx     u32 = u32(-1)
	create_colorchip_endy     u32 = u32(-1)
	choose_colorchip_submode  bool
	steal_settings_submode    bool
	add_input_submode         bool
	edit_color_submode        bool
	selected_colorchip        int

	test_mode bool

	cam_x     f64 = default_camera_pos_x
	cam_y     f64 = default_camera_pos_y
	move_down bool
	click_x   f32
	click_y   f32
	drag_x    f32
	drag_y    f32

	placement_mode bool
	place_down     bool
	place_start_x  u32 = u32(-1)
	place_start_y  u32
	place_end_x    u32
	place_end_y    u32

	selection_mode bool
	select_start_x u32 = u32(-1)
	select_start_y u32
	select_end_x   u32
	select_end_y   u32

	paste_mode bool

	load_gate_mode   bool
	gate_name_list   []string
	gate_x_ofst      f32 = 5.0
	gate_y_offset    f32 = 50.0
	gate_top_spacing f32 = 10.0
	gate_h           f32 = 50.0
	gate_w           f32 = 500.0

	save_gate_mode bool

	keyinput_mode bool
	key_pos       map[u8][][2]u32
	tmp_pos_x     u32 = u32(-1)
	tmp_pos_y     u32 = u32(-1)

	ui_width            f32                    = 50.0
	button_size         f32                    = 40.0
	button_left_padding f32                    = 5.0
	button_top_padding  f32                    = 5.0
	buttons             map[Buttons]ButtonData = button_map.clone()
	log                 string
	log_timer           int

	map             []Chunk
	map_name        string
	comp_running    bool
	pause           bool
	nb_updates      int = 5
	avg_update_time f64
	todo            []TodoInfo
	selected_item   Elem
	selected_ori    u64 = north
	copied          []PlaceInstruction
	actual_state    int
	nots            []Nots
	n_next_rid      u64 = 1
	n_states        [2][]bool
	diodes          []Diode
	d_next_rid      u64 = 1
	d_states        [2][]bool
	wires           []Wire
	w_next_rid      u64 = 1
	w_states        [2][]bool
	forced_states   [][2]u32
	colorchips      []ColorChip
	palette         Palette = palette_def
}

fn toml_palette_color(color string, doc toml.Doc) gg.Color {
	a := doc.value(color).array()
	return gg.Color{u8(a[0].u64()), u8(a[1].u64()), u8(a[2].u64()), u8(a[3].u64())}
}

fn (mut app App) load_palette() {}

fn (app App) scale_sprite(a [][]f32) [][]f32 {
	mut new_a := [][]f32{len: a.len, init: []f32{len: a[0].len}}
	for i, dir_a in a {
		for j, coo in dir_a {
			new_a[i][j] = coo * app.tile_size
		}
	}
	return new_a
}

fn on_frame(mut app App) {}

fn (mut app App) draw_ingame_ui_buttons() {}

fn (mut app App) draw_input_buttons() {}

fn (mut app App) draw_placing_preview() {}

fn (mut app App) draw_paste_preview() {}

fn (mut app App) draw_selection_box() {}

fn (mut app App) draw_map() {}

fn (app App) ingame_ui_button_click_to_nb(mouse_x f32, mouse_y f32) int {
	if !(mouse_x >= app.button_left_padding && mouse_x < app.button_size + app.button_left_padding) {
		return -1
	}
	return int((mouse_y - app.button_top_padding) / (app.button_top_padding + app.button_size))
}

fn (mut app App) handle_ingame_ui_button_interrac(b Buttons) {}

fn (app App) convert_button_nb_to_enum(nb int) ?Buttons {
	if nb == -1 {
		return none
	}
	unsafe {
		if app.selection_mode {
			for button in selec_buttons {
				if nb == app.buttons[button].pos {
					return button
				}
			}
		} else if app.load_gate_mode {
			if nb == app.buttons[.cancel_button].pos {
				return .cancel_button
			}
		} else if app.paste_mode {
			for button in paste_buttons {
				if nb == app.buttons[button].pos {
					return button
				}
			}
		} else if app.save_gate_mode {
			for button in save_gate_buttons {
				if nb == app.buttons[button].pos {
					return button
				}
			}
		} else if app.placement_mode {
			for button in placement_buttons {
				if nb == app.buttons[button].pos {
					return button
				}
			}
		} else if app.edit_mode {
			for button in edit_buttons {
				if nb == app.buttons[button].pos {
					return button
				}
			}
		} else {
			for button in no_mode_buttons {
				if nb == app.buttons[button].pos {
					return button
				}
			}
		}
	}
	return none
}

fn (app App) check_maps_button_click_y(pos int, mouse_y f32) bool {
	return mouse_y >= pos * (app.maps_top_spacing + app.maps_h) + app.maps_y_offset
		&& mouse_y < (pos + 1) * (app.maps_top_spacing + app.maps_h) + app.maps_y_offset
}

fn (app App) check_gates_button_click_y(pos int, mouse_y f32) bool {
	return mouse_y >= pos * (app.gate_top_spacing + app.gate_h) + app.gate_y_offset
		&& mouse_y < (pos + 1) * (app.gate_top_spacing + app.gate_h) + app.gate_y_offset
}

fn (mut app App) disable_all_ingame_modes() {}

fn (mut app App) go_map_menu() {}

fn (mut app App) load_saved_game(name string) {}

fn (mut app App) create_game() {
	dump('create_game')
	if !os.exists('saved_maps/${app.text_input}') {
		app.disable_all_ingame_modes()
		app.solo_menu = false

		app.map = []Chunk{}
		app.map_name = app.text_input
		app.text_input = ''
		app.pause = false
		app.nb_updates = 5
		app.todo = []
		app.selected_item = .not
		app.selected_ori = north
		app.copied = []
		app.actual_state = 0
		app.nots = []
		app.n_next_rid = 1
		app.n_states[0] = []
		app.n_states[1] = []
		app.diodes = []
		app.d_next_rid = 1
		app.d_states[0] = []
		app.d_states[1] = []
		app.wires = []
		app.w_next_rid = 1
		app.w_states[0] = []
		app.w_states[1] = []
		app.comp_running = true

		println('starting computation!!!')
		spawn app.computation_loop()
		app.cam_x = default_camera_pos_x
		app.cam_y = default_camera_pos_y
	} else {
		app.log('Map ${app.text_input} already exists')
	}
}

fn (mut app App) back_to_main_menu() {}

fn (mut app App) check_and_delete_colorchip_input(mouse_x f32, mouse_y f32) {}

fn (mut app App) check_and_select_or_delete_color_cc(mouse_x f32, mouse_y f32, e &gg.Event) {}

fn (mut app App) check_and_change_color_cc(mouse_x f32, mouse_y f32, e &gg.Event) {}

fn (mut app App) delete_colorchip_at(mouse_x f32, mouse_y f32) {}

fn (mut app App) create_colorchip_with_end_at(mouse_x f32, mouse_y f32) {}

fn (mut app App) load_gate_and_paste_mode(name string) {}

fn (mut app App) placement_released_at(mouse_x f32, mouse_y f32, e &gg.Event) {}

fn (mut app App) quit_map() {
	dump('quit_map')
	app.disable_all_ingame_modes()
	app.todo << TodoInfo{.quit, 0, 0, 0, 0, app.map_name}
	dump('waiting for save')
	for app.comp_running {}
	dump('finished save')
	app.main_menu = true
}

fn (mut app App) handle_ingame_ui_button_click(mouse_x f32, mouse_y f32) {}

fn (mut app App) handle_ingame_ui_button_keybind(nb int) {}

fn on_event(e &gg.Event, mut app App) {}

enum Elem as u8 {
	not
	diode
	on
	wire
	crossing
}

@[noreturn]
fn (mut app App) log_quit(message string) {
	mut f := os.open_append(logs_path) or {
		eprintln('FATAL: ${message}')
		panic(err)
	}
	f.write_string('FATAL: ${message}\n') or {
		eprintln('FATAL: ${message}')
		panic(err)
	}
	f.close()

	eprintln(message)
	print_backtrace()
	exit(1)
}

fn (mut app App) log(message string) {
	mut f := os.open_append(logs_path) or {
		println('LOG: ${message}')
		return
	}
	f.write_string('LOG: ${message}\n') or { println(message) }
	f.close()
	println(message)
	app.log = message
	app.log_timer = 180
}

struct PlaceInstruction {
mut:
	elem        Elem
	orientation u8

	rel_x i32
	rel_y i32
}

enum Todos {
	save_map
	removal
	paste
	load_gate
	save_gate
	place
	rotate
	copy
	quit
	flip_h
	flip_v
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
		for pos in app.forced_states {
			app.set_elem_state_by_pos(pos[0], pos[1], true)
		}
		cycle_end = time.now().unix_nano() + i64(1_000_000_000.0 / f32(app.nb_updates)) - i64(app.avg_update_time)
		mut done := []int{}
		for i, todo in app.todo {
			now = time.now().unix_nano()
			if now < cycle_end {
				dump(todo)
				match todo.task {
					.save_map {
						app.save_map(todo.name) or { app.log('save map: ${err}') }
					}
					.removal {
						app.removal(todo.x, todo.y, todo.x_end, todo.y_end)
					}
					.paste {
						app.paste(todo.x, todo.y)
					}
					.load_gate {
						app.load_gate_to_copied(todo.name) or {
							app.log('load gate to copied: ${err}')
						}
					}
					.save_gate {
						app.save_copied(todo.name) or { app.log('save copied: ${err}') }
					}
					.place {
						app.placement(todo.x, todo.y, todo.x_end, todo.y_end)
					}
					.rotate {
						app.rotate_copied()
					}
					.flip_h {
						app.flip_h()
					}
					.flip_v {
						app.flip_v()
					}
					.copy {
						app.copy(todo.x, todo.y, todo.x_end, todo.y_end)
					}
					.quit {
						dump('saving')
						app.save_map(todo.name) or { app.log('save map: ${err}') }
						dump('saved')
						app.comp_running = false
						app.back_to_main_menu()
					}
				}
				done << i
			} else {
				break
			}
		}
		for i in done.reverse() {
			app.todo.delete(i)
		}
		now = time.now().unix_nano()
		if app.todo.len == 0 && cycle_end - now >= 10000 {
			time.sleep((cycle_end - now) * time.nanosecond)
		}
		now = time.now().unix_nano()
		if !app.pause && app.comp_running {
			app.update_cycle()
		}
		app.avg_update_time = f32(time.now().unix_nano() - now) * 0.1 + 0.9 * app.avg_update_time
	}
}

fn (mut app App) save_copied(name_ string) ! {}

fn (mut app App) load_map(map_name string) ! {}

fn (mut app App) save_map(map_name string) ! {
	mut file := os.open_file(maps_path + map_name, 'w') or {
		app.log('${@LOCATION}: ${err}')
		return
	}
	defer {
		file.close()
	}
	dump('file opened')
	mut offset := u64(0)
	save_version := u32(0)
	file.write_raw_at(save_version, offset) or {
		app.log('${@LOCATION}: ${err}')
		return
	}
	dump('save version written')
	offset += sizeof(save_version)
	file.write_raw_at(i64(app.map.len), offset) or {
		app.log('${@LOCATION}: ${err}')
		return
	}
	offset += sizeof(i64)
	dump(offset)
	for mut chunk in app.map {
		file.write_raw_at(chunk.x, offset) or {
			app.log('${@LOCATION}: ${err}')
			return
		}
		offset += sizeof(chunk.x)
		file.write_raw_at(chunk.y, offset) or {
			app.log('${@LOCATION}: ${err}')
			return
		}
		offset += sizeof(chunk.y)
		unsafe {
			file.write_ptr_at(chunk.id_map, chunk_size * chunk_size * int(sizeof(u64)),
				offset)
		}
		offset += chunk_size * chunk_size * sizeof(u64)
	}
	file.write_raw_at(app.actual_state, offset) or {
		app.log('${@LOCATION}: ${err}')
		return
	}
	offset += sizeof(app.actual_state)
	file.write_raw_at(i64(app.nots.len), offset) or {
		app.log('${@LOCATION}: ${err}')
		return
	}
	offset += sizeof(i64)
	unsafe { file.write_ptr_at(app.nots, app.nots.len * int(sizeof(Nots)), offset) }
	offset += u64(app.nots.len) * sizeof(Nots)
	unsafe {
		file.write_ptr_at(app.n_states[app.actual_state].data, app.nots.len * int(sizeof(bool)),
			offset)
	}
	offset += u64(app.diodes.len) * sizeof(bool)
	dump(offset)
	file.write_raw_at(i64(app.diodes.len), offset) or {
		app.log('${@LOCATION}: ${err}')
		return
	}
	offset += sizeof(i64)
	unsafe { file.write_ptr_at(app.diodes, app.diodes.len * int(sizeof(Diode)), offset) }
	offset += u64(app.diodes.len) * sizeof(Diode)
	unsafe {
		file.write_ptr_at(app.d_states[app.actual_state].data, app.diodes.len * int(sizeof(bool)),
			offset)
	}
	offset += u64(app.diodes.len) * sizeof(bool)
	dump(offset)
	file.write_raw_at(i64(app.wires.len), offset) or {
		app.log('${@LOCATION}: ${err}')
		return
	}
	offset += sizeof(i64)
	for wire in app.wires {
		file.write_raw_at(wire.rid, offset) or {
			app.log('${@LOCATION}: ${err}')
			return
		}
		offset += sizeof(u64)
		file.write_raw_at(i64(wire.inps.len), offset) or {
			app.log('${@LOCATION}: ${err}')
			return
		}
		offset += sizeof(i64)
		unsafe { file.write_ptr_at(wire.inps.data, wire.inps.len * int(sizeof(u64)), offset) }
		file.write_raw_at(i64(wire.outs.len), offset) or {
			app.log('${@LOCATION}: ${err}')
			return
		}
		offset += sizeof(i64)
		unsafe { file.write_ptr_at(wire.outs.data, wire.outs.len * int(sizeof(u64)), offset) }
		file.write_raw_at(i64(wire.cable_coords.len), offset) or {
			app.log('${@LOCATION}: ${err}')
			return
		}
		offset += sizeof(i64)
		for cable in wire.cable_coords {
			file.write_raw_at(cable[0], offset) or {
				app.log('${@LOCATION}: ${err}')
				return
			}
			offset += sizeof(u32)
			file.write_raw_at(cable[1], offset) or {
				app.log('${@LOCATION}: ${err}')
				return
			}
			offset += sizeof(u32)
		}
	}
	unsafe {}
	offset += u64(app.wires.len) * sizeof(bool)
	dump(offset)
	file.write_raw_at(i64(app.forced_states.len), offset) or {
		app.log('${@LOCATION}: ${err}')
		return
	}
	offset += sizeof(i64)
	for pos in app.forced_states {
		file.write_raw_at(pos[0], offset) or {
			app.log('${@LOCATION}: ${err}')
			return
		}
		offset += sizeof(u32)
		file.write_raw_at(pos[1], offset) or {
			app.log('${@LOCATION}: ${err}')
			return
		}
		offset += sizeof(u32)
	}
	dump(offset)
	file.write_raw_at(i64(app.colorchips.len), offset) or {
		app.log('${@LOCATION}: ${err}')
		return
	}
	offset += sizeof(i64)
	for cc in app.colorchips {
		file.write_raw_at(cc.x, offset) or {
			app.log('${@LOCATION}: ${err}')
			return
		}
		offset += sizeof(u32)
		file.write_raw_at(cc.y, offset) or {
			app.log('${@LOCATION}: ${err}')
			return
		}
		offset += sizeof(u32)
		file.write_raw_at(cc.w, offset) or {
			app.log('${@LOCATION}: ${err}')
			return
		}
		offset += sizeof(u32)
		file.write_raw_at(cc.h, offset) or {
			app.log('${@LOCATION}: ${err}')
			return
		}
		offset += sizeof(u32)
		dump(offset)
		file.write_raw_at(i64(cc.colors.len), offset) or {
			app.log('${@LOCATION}: ${err}')
			return
		}
		offset += sizeof(i64)
		for color in cc.colors {
			file.write_raw_at(color.r, offset) or {
				app.log('${@LOCATION}: ${err}')
				return
			}
			offset += sizeof(u8)
			file.write_raw_at(color.g, offset) or {
				app.log('${@LOCATION}: ${err}')
				return
			}
			offset += sizeof(u8)
			file.write_raw_at(color.b, offset) or {
				app.log('${@LOCATION}: ${err}')
				return
			}
			offset += sizeof(u8)
		}
		dump(offset)
		file.write_raw_at(i64(cc.inputs.len), offset) or {
			app.log('${@LOCATION}: ${err}')
			return
		}
		offset += sizeof(i64)
		for i in cc.inputs {
			file.write_raw_at(i[0], offset) or {
				app.log('${@LOCATION}: ${err}')
				return
			}
			offset += sizeof(u32)
			file.write_raw_at(i[1], offset) or {
				app.log('${@LOCATION}: ${err}')
				return
			}
			offset += sizeof(u32)
		}
	}
	dump(offset)
}

fn (mut app App) load_gate_to_copied(gate_name string) ! {}

fn (mut app App) flip_v() {}

fn (mut app App) flip_h() {}

fn (mut app App) rotate_copied() {}

fn (mut app App) paste(x_start u32, y_start u32) {}

fn (mut app App) test_validity(_x_start u32, _y_start u32, _x_end u32, _y_end u32) (u32, u32, string) {
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
	for x in x_start .. x_end {
		for y in y_start .. y_end {
			chunk_i := app.get_chunkmap_idx_at_coords(x, y)
			mut chunkmap := &app.map[chunk_i].id_map
			x_map := x % chunk_size
			y_map := y % chunk_size
			id := unsafe { chunkmap[x_map][y_map] }
			if id == 0x0 {
				continue
			}
			if id == elem_crossing_bits {
				continue
			}
			ori := id & ori_mask
			step := match ori {
				north {
					[0, 1]!
				}
				south {
					[0, -1]!
				}
				west {
					[1, 0]!
				}
				east {
					[-1, 0]!
				}
				else {
					app.log_quit('${@LOCATION} not a valid orientation')
				}
			}
			match id & elem_type_mask {
				elem_not_bits, elem_diode_bits {
					inp_id := app.next_gate_id(x, y, -step[0], -step[1], ori)
					if inp_id & id_mask != app.get_input(id) & id_mask {
						return x, y, 'problem: input is not the preceding gate'
					}
					inp_old_state, _ := app.get_elem_state_idx_by_id(inp_id, (app.actual_state + 1) % 2)
					if id & elem_type_mask == elem_not_bits {
						state, _ := app.get_elem_state_idx_by_id(id, app.actual_state)
						if state == inp_old_state {
							return x, y, 'problem: NOT did not inverse the input state'
						}
						if (id & on_bits != 0) == inp_old_state {
							return x, y, 'problem: NOT(map state) did not inverse the input state'
						}
					} else {
						state, _ := app.get_elem_state_idx_by_id(id, app.actual_state)
						if state != inp_old_state {
							return x, y, 'problem: Diode did not match the input state'
						}
						if (id & on_bits != 0) != inp_old_state {
							return x, y, 'problem: Diode(map state) did not match the input state'
						}
					}
				}
				elem_on_bits {}
				elem_wire_bits {
					s_adj_id, s_is_input, _, _ := app.wire_next_gate_id_coo(x, y, 0, 1)
					n_adj_id, n_is_input, _, _ := app.wire_next_gate_id_coo(x, y, 0, -1)
					e_adj_id, e_is_input, _, _ := app.wire_next_gate_id_coo(x, y, 1, 0)
					w_adj_id, w_is_input, _, _ := app.wire_next_gate_id_coo(x, y, -1,
						0)
					wire_state, wire_idx := app.get_elem_state_idx_by_id(id, app.actual_state)
					if (id & on_bits != 0) != wire_state {
						return x, y, "problem: cable(map state)'s state is not the same as the wire"
					}
					if s_adj_id != empty_id {
						if s_adj_id & elem_type_mask == elem_wire_bits {
							if id & id_mask != s_adj_id & id_mask {
								return x, y, 'problem: south wire(${s_adj_id & id_mask}) has a different id from the wire(${id & id_mask})'
							}
						} else {
							if s_is_input {
								if s_adj_id & id_mask !in app.wires[wire_idx].inps.map(it & id_mask) {
									return x, y, "problem: south(${s_adj_id}) is not in the wire(${id})'s input"
								}
								s_old_state, _ := app.get_elem_state_idx_by_id(s_adj_id,
									(app.actual_state + 1) % 2)
								if s_old_state && !wire_state {
									return x, y, 'problem: wire did not match south On state'
								}
							} else {
								if s_adj_id & id_mask !in app.wires[wire_idx].outs.map(it & id_mask) {
									return x, y, "problem: south(${s_adj_id}) is not in the wire(${id})'s output"
								}
							}
						}
					}
					if n_adj_id != empty_id {
						if n_adj_id & elem_type_mask == elem_wire_bits {
							if id & id_mask != n_adj_id & id_mask {
								return x, y, 'problem: north wire(${n_adj_id & id_mask}) has a different id from the wire(${id & id_mask})'
							}
						} else {
							if n_is_input {
								if n_adj_id & id_mask !in app.wires[wire_idx].inps.map(it & id_mask) {
									return x, y, "problem: north(${n_adj_id & id_mask}) is not in the wire(${id & id_mask})'s input"
								}
								n_old_state, _ := app.get_elem_state_idx_by_id(n_adj_id,
									(app.actual_state + 1) % 2)
								if n_old_state && !wire_state {
									return x, y, 'problem: wire did not match north On state'
								}
							} else {
								if n_adj_id & id_mask !in app.wires[wire_idx].outs.map(it & id_mask) {
									return x, y, "problem: north(${n_adj_id & id_mask}) is not in the wire(${id & id_mask})'s output"
								}
							}
						}
					}
					if e_adj_id != empty_id {
						if e_adj_id & elem_type_mask == elem_wire_bits {
							if id & id_mask != e_adj_id & id_mask {
								return x, y, 'problem: east wire(${e_adj_id & id_mask}) has a different id from the wire(${id & id_mask})'
							}
						} else {
							if e_is_input {
								if e_adj_id & id_mask !in app.wires[wire_idx].inps.map(it & id_mask) {
									return x, y, "problem: east(${e_adj_id & id_mask}) is not in the wire(${id & id_mask})'s input"
								}
								e_old_state, _ := app.get_elem_state_idx_by_id(e_adj_id,
									(app.actual_state + 1) % 2)
								if e_old_state && !wire_state {
									return x, y, 'problem: wire did not match east On state'
								}
							} else {
								if e_adj_id & id_mask !in app.wires[wire_idx].outs.map(it & id_mask) {
									return x, y, "problem: east(${e_adj_id & id_mask}) is not in the wire(${id & id_mask})'s output"
								}
							}
						}
					}
					if w_adj_id != empty_id {
						if w_adj_id & elem_type_mask == elem_wire_bits {
							if id & id_mask != w_adj_id & id_mask {
								return x, y, 'problem: west wire(${w_adj_id & id_mask}) has a different id from the wire(${id & id_mask})'
							}
						} else {
							if w_is_input {
								if w_adj_id & id_mask !in app.wires[wire_idx].inps.map(it & id_mask) {
									return x, y, "problem: west(${w_adj_id & id_mask}) is not in the wire(${id & id_mask})'s input"
								}
								w_old_state, _ := app.get_elem_state_idx_by_id(w_adj_id,
									(app.actual_state + 1) % 2)
								if w_old_state && !wire_state {
									return x, y, 'problem: wire did not match west On state'
								}
							} else {
								if w_adj_id & id_mask !in app.wires[wire_idx].outs.map(it & id_mask) {
									return x, y, "problem: west(${w_adj_id & id_mask}) is not in the wire(${id & id_mask})'s output"
								}
							}
						}
					}
				}
				else {
					app.log_quit('${@LOCATION} should not get into this else')
				}
			}
		}
	}
	return 0, 0, ''
}

fn (mut app App) fuzz(_x_start u32, _y_start u32, _x_end u32, _y_end u32) {}

fn (mut app App) copy(_x_start u32, _y_start u32, _x_end u32, _y_end u32) {}

fn (mut app App) removal(_x_start u32, _y_start u32, _x_end u32, _y_end u32) {}

fn (mut app App) separate_wires(coo_adj_wires [][2]u32, id u64) {}

fn which_wire(new_wires []Wire, coo [2]u32) u64 {
	for wire in new_wires {
		i := wire.cable_coords.index(coo)
		if i != -1 {
			return wire.rid
		}
	}
	return u64(-1)
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
	mut x_ori, mut y_ori := match app.selected_ori {
		north { 0, -1 }
		south { 0, 1 }
		east { 1, 0 }
		west { -1, 0 }
		else { app.log_quit('${@LOCATION} unknown orientation') }
	}
	match app.selected_item {
		.not {
			for x in x_start .. x_end + 1 {
				for y in y_start .. y_end + 1 {
					chunk_i := app.get_chunkmap_idx_at_coords(x, y)
					mut chunkmap := &app.map[chunk_i].id_map
					x_map := x % chunk_size
					y_map := y % chunk_size
					if unsafe { chunkmap[x_map][y_map] } != empty_id {
						continue
					}

					id := elem_not_bits | app.n_next_rid | app.selected_ori
					unsafe {
						chunkmap[x_map][y_map] = id
					}
					inp_id := app.next_gate_id(x, y, -x_ori, -y_ori, id & ori_mask)
					app.nots << Nots{id & rid_mask, inp_id, x, y}
					app.n_states[0] << false
					app.n_states[1] << false

					out_id := app.next_gate_id(x, y, x_ori, y_ori, id & ori_mask)
					app.add_input(out_id, id)
					app.add_output(inp_id, id)

					app.n_next_rid++
				}
			}
		}
		.diode {
			for x in x_start .. x_end + 1 {
				for y in y_start .. y_end + 1 {
					chunk_i := app.get_chunkmap_idx_at_coords(x, y)
					mut chunkmap := &app.map[chunk_i].id_map
					x_map := x % chunk_size
					y_map := y % chunk_size
					if unsafe { chunkmap[x_map][y_map] } != empty_id {
						continue
					}

					id := elem_diode_bits | app.d_next_rid | app.selected_ori
					unsafe {
						chunkmap[x_map][y_map] = id
					}
					inp_id := app.next_gate_id(x, y, -x_ori, -y_ori, id & ori_mask)
					app.diodes << Diode{id & rid_mask, inp_id, x, y}
					app.d_states[0] << false
					app.d_states[1] << false

					out_id := app.next_gate_id(x, y, x_ori, y_ori, id & ori_mask)
					app.add_input(out_id, id)
					app.add_output(inp_id, id)

					app.d_next_rid++
				}
			}
		}
		.on {
			for x in x_start .. x_end + 1 {
				for y in y_start .. y_end + 1 {
					chunk_i := app.get_chunkmap_idx_at_coords(x, y)
					mut chunkmap := &app.map[chunk_i].id_map
					x_map := x % chunk_size
					y_map := y % chunk_size
					if unsafe { chunkmap[x_map][y_map] } != empty_id {
						continue
					}

					id := elem_on_bits | on_bits | app.selected_ori
					unsafe {
						chunkmap[x_map][y_map] = id
					}
					out_id := app.next_gate_id(x, y, x_ori, y_ori, id & ori_mask)
					app.add_input(out_id, id)
				}
			}
		}
		.wire {
			for x in x_start .. x_end + 1 {
				for y in y_start .. y_end + 1 {
					chunk_i := app.get_chunkmap_idx_at_coords(x, y)
					mut chunkmap := &app.map[chunk_i].id_map
					x_map := x % chunk_size
					y_map := y % chunk_size
					if unsafe { chunkmap[x_map][y_map] } != empty_id {
						continue
					}

					mut adjacent_wires := []u64{}
					mut adjacent_inps := []u64{}
					mut adjacent_outs := []u64{}
					for coo in [[0, 1]!, [0, -1]!, [1, 0]!, [-1, 0]!]! {
						adj_id, is_input, _, _ := app.wire_next_gate_id_coo(x, y, coo[0],
							coo[1])
						if adj_id == empty_id {
						} else if adj_id & elem_type_mask == elem_wire_bits {
							adjacent_wires << adj_id & id_mask
						} else {
							if is_input {
								adjacent_inps << adj_id & id_mask
							} else {
								adjacent_outs << adj_id & id_mask
							}
						}
					}

					mut tmp_adj_wires := []u64{}
					for aw in adjacent_wires {
						if aw !in tmp_adj_wires {
							tmp_adj_wires << aw
						}
					}
					adjacent_wires = tmp_adj_wires.clone()

					if adjacent_wires.len > 1 {
						app.join_wires(mut adjacent_wires)
					} else if adjacent_wires.len == 0 {
						app.wires << Wire{
							rid: app.w_next_rid
						}
						adjacent_wires << app.w_next_rid | elem_wire_bits
						app.w_states[0] << false
						app.w_states[1] << false

						app.w_next_rid++
					}
					_, first_i := app.get_elem_state_idx_by_id(adjacent_wires[0], 0)

					unsafe {
						if app.w_states[app.actual_state][first_i] {
							chunkmap[x_map][y_map] = elem_wire_bits | adjacent_wires[0] | on_bits
						} else {
							chunkmap[x_map][y_map] = elem_wire_bits | adjacent_wires[0]
						}
					}
					app.wires[first_i].cable_coords << [x, y]!
					app.wires[first_i].inps << adjacent_inps
					app.wires[first_i].outs << adjacent_outs

					for inp_id in adjacent_inps {
						app.add_output(inp_id, adjacent_wires[0])
					}
					for out_id in adjacent_outs {
						app.add_input(out_id, adjacent_wires[0])
					}
				}
			}
		}
		.crossing {
			for x in x_start .. x_end + 1 {
				for y in y_start .. y_end + 1 {
					chunk_i := app.get_chunkmap_idx_at_coords(x, y)
					mut chunkmap := &app.map[chunk_i].id_map
					x_map := x % chunk_size
					y_map := y % chunk_size
					if unsafe { chunkmap[x_map][y_map] } != empty_id {
						continue
					}

					unsafe {
						chunkmap[x_map][y_map] = elem_crossing_bits
					}
					s_adj_id, s_is_input, _, _ := app.wire_next_gate_id_coo(x, y, 0, 1)
					n_adj_id, n_is_input, _, _ := app.wire_next_gate_id_coo(x, y, 0, -1)
					e_adj_id, e_is_input, _, _ := app.wire_next_gate_id_coo(x, y, 1, 0)
					w_adj_id, w_is_input, _, _ := app.wire_next_gate_id_coo(x, y, -1,
						0)
					if s_adj_id != empty_id && n_adj_id != empty_id {
						if s_adj_id & elem_type_mask == elem_wire_bits
							&& n_adj_id & elem_type_mask == elem_wire_bits {
							mut adjacent_wires := [s_adj_id, n_adj_id]

							mut tmp_adj_wires := []u64{}
							for aw in adjacent_wires {
								if aw !in tmp_adj_wires {
									tmp_adj_wires << aw
								}
							}
							adjacent_wires = tmp_adj_wires.clone()
							app.join_wires(mut adjacent_wires)
						} else if s_adj_id & elem_type_mask == elem_wire_bits {
							if n_is_input {
								app.add_input(s_adj_id, n_adj_id)
								app.add_output(n_adj_id, s_adj_id)
							} else {
								app.add_input(n_adj_id, s_adj_id)
								app.add_output(s_adj_id, n_adj_id)
							}
						} else if n_adj_id & elem_type_mask == elem_wire_bits {
							if s_is_input {
								app.add_input(n_adj_id, s_adj_id)
								app.add_output(s_adj_id, n_adj_id)
							} else {
								app.add_input(s_adj_id, n_adj_id)
								app.add_output(n_adj_id, s_adj_id)
							}
						} else {
							if s_is_input && !n_is_input {
								app.add_input(n_adj_id, s_adj_id)
								app.add_output(s_adj_id, n_adj_id)
							} else if !s_is_input && n_is_input {
								app.add_input(s_adj_id, n_adj_id)
								app.add_output(n_adj_id, s_adj_id)
							}
						}
					}
					if e_adj_id != empty_id && w_adj_id != empty_id {
						if e_adj_id & elem_type_mask == elem_wire_bits
							&& w_adj_id & elem_type_mask == elem_wire_bits {
							mut adjacent_wires := [e_adj_id, w_adj_id]

							mut tmp_adj_wires := []u64{}
							for aw in adjacent_wires {
								if aw !in tmp_adj_wires {
									tmp_adj_wires << aw
								}
							}
							adjacent_wires = tmp_adj_wires.clone()
							app.join_wires(mut adjacent_wires)
						} else if e_adj_id & elem_type_mask == elem_wire_bits {
							if w_is_input {
								app.add_input(e_adj_id, w_adj_id)
								app.add_output(w_adj_id, e_adj_id)
							} else {
								app.add_input(w_adj_id, e_adj_id)
								app.add_output(e_adj_id, w_adj_id)
							}
						} else if w_adj_id & elem_type_mask == elem_wire_bits {
							if e_is_input {
								app.add_input(w_adj_id, e_adj_id)
								app.add_output(e_adj_id, w_adj_id)
							} else {
								app.add_input(e_adj_id, w_adj_id)
								app.add_output(w_adj_id, e_adj_id)
							}
						} else {
							if e_is_input && !w_is_input {
								app.add_input(w_adj_id, e_adj_id)
								app.add_output(e_adj_id, w_adj_id)
							} else if !e_is_input && w_is_input {
								app.add_input(e_adj_id, w_adj_id)
								app.add_output(w_adj_id, e_adj_id)
							}
						}
					}
				}
			}
		}
	}
}

fn (mut app App) join_wires(mut adjacent_wires []u64) {}

fn (mut app App) get_input(elem_id u64) u64 {
	if elem_id != empty_id && elem_id != elem_crossing_bits {
		if elem_id & elem_type_mask == 0b00 {
			_, idx := app.get_elem_state_idx_by_id(elem_id, 0)
			return app.nots[idx].inp
		} else if elem_id & elem_type_mask == 0b01 {
			_, idx := app.get_elem_state_idx_by_id(elem_id, 0)
			return app.diodes[idx].inp
		} else if elem_id & elem_type_mask == 0b10 {
		} else if elem_id & elem_type_mask == 0b11 {
		}
	}
	return empty_id
}

fn (mut app App) add_input(elem_id u64, input_id u64) {}

fn (mut app App) remove_input(elem_id u64, input_id u64) {}

fn (mut app App) add_output(elem_id u64, output_id u64) {}

fn (mut app App) remove_output(elem_id u64, output_id u64) {}

fn (mut app App) wire_next_gate_id_coo(x u32, y u32, x_dir int, y_dir int) (u64, bool, i64, i64) {
	conv_x := u32(int(x) + x_dir)
	conv_y := u32(int(y) + y_dir)
	mut chunk_i := app.get_chunkmap_idx_at_coords(conv_x, conv_y)
	mut next_chunkmap := &app.map[chunk_i].id_map
	mut next_id := unsafe { next_chunkmap[conv_x % chunk_size][conv_y % chunk_size] }
	mut input := false

	if next_id == elem_crossing_bits {
		mut x_off := i64(x_dir)
		mut y_off := i64(y_dir)
		for next_id == elem_crossing_bits {
			x_off += x_dir
			y_off += y_dir
			x_conv := u32(i64(x) + x_off)
			y_conv := u32(i64(y) + y_off)
			chunk_i = app.get_chunkmap_idx_at_coords(x_conv, y_conv)
			next_chunkmap = &app.map[chunk_i].id_map
			next_id = unsafe { next_chunkmap[x_conv % chunk_size][y_conv % chunk_size] }
		}
		next_id2, input2, _, _ := app.wire_next_gate_id_coo(u32(int(x) + x_off - x_dir),
			u32(int(y) + y_off - y_dir), x_dir, y_dir)
		return next_id2, input2, x_off, y_off
	} else if next_id == empty_id {
		next_id = empty_id
	} else if next_id & elem_type_mask == elem_on_bits {
	} else if next_id & elem_type_mask == elem_wire_bits {
	} else if next_id & elem_type_mask == elem_not_bits {
	} else if next_id & elem_type_mask == elem_diode_bits {
		ori, opposite_ori := match [x_dir, y_dir]! {
			[0, 1]! {
				south, north
			}
			[0, -1]! {
				north, south
			}
			[1, 0]! {
				east, west
			}
			[-1, 0]! {
				west, east
			}
			else {
				app.log_quit('${@LOCATION} not a valid step for an orientation')
			}
		}
		if next_id & ori_mask == ori {
			input = false
		} else if next_id & ori_mask == opposite_ori {
			input = true
		} else {
			next_id = empty_id
		}
	}
	return next_id, input, x_dir, y_dir
}

fn (mut app App) next_gate_id(x u32, y u32, x_dir int, y_dir int, gate_ori u64) u64 {
	conv_x := u32(int(x) + x_dir)
	conv_y := u32(int(y) + y_dir)
	mut chunk_i := app.get_chunkmap_idx_at_coords(conv_x, conv_y)
	mut next_chunkmap := &app.map[chunk_i].id_map
	mut next_id := unsafe { next_chunkmap[conv_x % chunk_size][conv_y % chunk_size] }

	if next_id == elem_crossing_bits {
		mut x_off := i64(x_dir)
		mut y_off := i64(y_dir)
		for next_id == elem_crossing_bits {
			x_off += x_dir
			y_off += y_dir
			x_conv := u32(i64(x) + x_off)
			y_conv := u32(i64(y) + y_off)
			chunk_i = app.get_chunkmap_idx_at_coords(x_conv, y_conv)
			next_chunkmap = &app.map[chunk_i].id_map
			next_id = unsafe { next_chunkmap[x_conv % chunk_size][y_conv % chunk_size] }
		}
		return app.next_gate_id(u32(int(x) + x_off - x_dir), u32(int(y) + y_off - y_dir),
			x_dir, y_dir, gate_ori)
	} else if next_id == empty_id {
		next_id = empty_id
	} else if next_id & elem_type_mask == elem_on_bits {
		step_ori := match [x_dir, y_dir]! {
			[0, 1]! {
				south
			}
			[0, -1]! {
				north
			}
			[1, 0]! {
				east
			}
			[-1, 0]! {
				west
			}
			else {
				app.log_quit('${@LOCATION} not a valid step for an orientation')
			}
		}
		if step_ori == gate_ori || next_id & ori_mask != gate_ori {
			next_id = empty_id
		}
	} else if next_id & elem_type_mask == elem_wire_bits {
	} else if next_id & elem_type_mask == elem_not_bits {
		if next_id & ori_mask != gate_ori {
			next_id = empty_id
		}
	} else if next_id & elem_type_mask == elem_diode_bits {
		if next_id & ori_mask != gate_ori {
			next_id = empty_id
		}
	}
	return next_id
}

fn (mut app App) set_elem_state_by_pos(x u32, y u32, new_state bool) {}

fn (mut app App) update_cycle() {}

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

fn (mut app App) get_elem_state_idx_by_id(id u64, previous int) (bool, int) {
	concerned_state := (app.actual_state + previous) % 2
	rid := id & rid_mask

	if id == empty_id {
	}
	if id & elem_type_mask == elem_on_bits {
	} else if id & elem_type_mask == elem_not_bits {
	} else if id & elem_type_mask == elem_diode_bits {
	} else if id & elem_type_mask == elem_wire_bits {
	}
	app.log_quit('${@LOCATION} id not found in get_elem_state_idx_by_id: ${id & rid_mask}')
}

struct Chunk {
mut:
	x      u32
	y      u32
	id_map [chunk_size][chunk_size]u64
}

struct Nots {
	rid u64
mut:
	inp u64

	x u32
	y u32
}

struct Diode {
	rid u64
mut:
	inp u64

	x u32
	y u32
}

struct Wire {
mut:
	rid          u64
	inps         []u64
	outs         []u64
	cable_coords [][2]u32
}
