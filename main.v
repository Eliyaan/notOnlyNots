module main

import math { pow }
import os
import rand
import time
import gg
import sokol.sgl
import toml

@[mingw]
#flag windows --static

// NEXT BIG STEPS:
// MULTITHREADING
// MULTIPLAYER
// PUZZLES / LEADERBOARDS

const game_data_path = 'game_data/'
const player_data_path = 'player_data/'
const sprites_path = game_data_path + 'sprites/'
const logs_path = player_data_path + 'logs'
const palette_path = player_data_path + 'palette.toml'
const font_path = game_data_path + 'fonts/0xProtoNerdFontMono-Regular.ttf'
const default_button_color = gg.Color{75, 108, 136, 255}
const default_colorchip_color_on = gg.Color{197, 209, 227, 255}
const default_colorchip_color_off = gg.Color{47, 49, 54, 255}
const default_camera_pos_x = f64(2_000_000_000.0)
const default_camera_pos_y = f64(2_000_000_000.0)
const gates_path = player_data_path + 'saved_gates/'
const maps_path = player_data_path + 'saved_maps/'
const empty_id = u64(0)
const on_bits = u64(0x2000_0000_0000_0000) // 0010_0000_000...
const elem_not_bits = u64(0x0000_0000_0000_0000) // 0000_0000_000...
const elem_diode_bits = u64(0x4000_0000_0000_0000) // 0100_0000_000...
const elem_on_bits = u64(0x8000_0000_0000_0000) // 1010_0000_000...  always on
const elem_wire_bits = u64(0xC000_0000_0000_0000) // 1100_0000_000...
const elem_crossing_bits = u64(0xFFFF_FFFF_FFFF_FFFF) // 1111_1111_...
// x++=east y++=south
const north = u64(0x0)
const south = u64(0x0800_0000_0000_0000) // 0000_1000..
const west = u64(0x1000_0000_0000_0000) // 0001_000...
const east = u64(0x1800_0000_0000_0000) // 0001_100..
const rid_mask = u64(0x07FF_FFFF_FFFF_FFFF) // 0000_0111_11111... bit map to get the real id with &
const elem_type_mask = u64(0xC000_0000_0000_0000) // 1100_0000...
const id_mask = rid_mask | elem_type_mask // unique
const ori_mask = u64(0x1800_0000_0000_0000) // 0001_1000...
const chunk_size = 128
const chunk_power = 7
const chunk_bitmask = chunk_size - 1
const chunk_inv_bitmask = ~chunk_bitmask
const invalid_coo = u32(-1)
const cardinal_coords = [[0, 1]!, [0, -1]!, [1, 0]!, [-1, 0]!]!
const diode_poly_unscaled = [
	[f32(0.2), 1.0, 0.4, 0.0, 0.6, 0.0, 0.8, 1.0], // north
	[f32(0.2), 0.0, 0.8, 0.0, 0.6, 1.0, 0.4, 1.0], // south
	[f32(1.0), 0.2, 1.0, 0.8, 0.0, 0.6, 0.0, 0.4], // west
	[f32(0.0), 0.2, 1.0, 0.4, 1.0, 0.6, 0.0, 0.8], // east
]
const not_rect_unscaled = [// x, y, width, height
	[f32(0.33), 0.0, 0.33, 0.2], // north
	[f32(0.33), 0.8, 0.33, 0.2], // south
	[f32(0.0), 0.33, 0.2, 0.33], // west
	[f32(0.8), 0.33, 0.2, 0.33], // east
]
const not_poly_unscaled = [
	[f32(0.2), 1.0, 0.5, 0.0, 0.8, 1.0], // north
	[f32(0.2), 0.0, 0.8, 0.0, 0.5, 1.0], // south
	[f32(1.0), 0.2, 1.0, 0.8, 0.0, 0.5], // west
	[f32(0.0), 0.2, 1.0, 0.5, 0.0, 0.8], // east
]
const on_poly_unscaled = [
	[f32(0.2), 0.6, 0.4, 0.0, 0.6, 0.0, 0.8, 0.6], // north
	[f32(0.2), 0.4, 0.8, 0.4, 0.6, 1.0, 0.4, 1.0], // south
	[f32(0.6), 0.2, 0.6, 0.8, 0.0, 0.6, 0.0, 0.4], // west
	[f32(0.4), 0.2, 1.0, 0.4, 1.0, 0.6, 0.4, 0.8], // east
]
const nots_array_default = [Nots{
	x: invalid_coo
}]

const diode_array_default = [Diode{
	x: invalid_coo
}]

const wire_array_default = [Wire{
	cable_coords: [Coo{invalid_coo, 0}]
}]

// UI sizes
const default_win_height = f32(800.0)
const default_win_width = f32(1422.0)
const log_cfg = gg.TextCfg{
	size:  16
	color: gg.black
}
const log_width = 200
const log_interline_spacing = 4
const log_border = 5
const selected_cc_circle_r = 6
const input_box_off = 10.0
const input_text_off_x = 15.0
const input_text_off_y = 10.0
const input_box_w = 250.0
const input_box_h = 35.0
const info_text_off = 10.0
const info_text_spacing = 20.0
const button_solo_w = f32(244.0)
const button_solo_h = f32(125.0)
const button_solo_x = f32(900.0) - button_solo_w / 2.0
const button_solo_y = f32(500.0) - button_solo_h / 2.0
const button_quit_size = f32(50.0)
const btn_quit_ofst = f32(20.0)
const btn_quit_y = f32(700.0)
const maps_x_offset = f32(50.0)
const maps_y_offset = f32(50.0)
const maps_top_spacing = f32(0.0)
const maps_w = f32(500.0)
const button_new_map_x = f32(5.0)
const button_new_map_y = f32(5.0)
const button_new_map_size = f32(40.0)
const maps_h = button_new_map_size
const btn_back_x = f32(5.0)
const btn_back_y = f32(50.0)
const btn_back_s = f32(40.0)
const text_field_x = f32(50.0)
const text_field_y = f32(5.0)
const editmenu_offset_x = default_win_width * 2 / 3
const editmenu_offset_y = f32(30.0)
const editmenu_offset_inputs_x = f32(60.0)
const editmenu_offset_inputs_y = f32(10.0)
const editmenu_offset_colors_x = f32(60.0)
const editmenu_offset_colors_y = f32(120.0)
const editmenu_inputsize = f32(20.0)
const editmenu_input_x_space = f32(5.0)
const editmenu_rgb_y = f32(60.0)
const editmenu_rgb_h = f32(40.0)
const editmenu_rgb_w = f32(40.0)
const editmenu_r_x = f32(60.0)
const editmenu_g_x = f32(110.0)
const editmenu_b_x = f32(160.0)
const editmenu_colorsize = f32(20.0)
const editmenu_colorborder = f32(6.0)
const gate_text_off_x = 10.0
const gate_x_ofst = f32(5.0)
const gate_y_offset = f32(50.0)
const gate_top_spacing = f32(10.0)
const gate_h = f32(50.0)
const gate_w = f32(500.0)
const ui_width = f32(50.0)
const button_size = f32(40.0)
const button_left_padding = f32(5.0)
const button_top_padding = f32(5.0)

enum Buttons {
	cancel_button     // escapes modes
	confirm_save_gate // save gate mode
	selection_button  // no mode
	rotate_copy       // paste mode
	copy_button       // selection mode
	choose_colorchip  // edit mode
	load_gate         // no/paste
	save_gate         // selection
	edit_color        // edit
	item_nots         // no/placement
	create_color_chip // selection
	add_input         // edit
	item_diode        // no/placement
	copy_settings     // edit
	item_crossing     // no/placement
	delete_colorchip  // edit
	item_on           // no/placement
	item_wire         // no/placement
	speed             // no
	slow              // no
	pause             // no
	paste             // no/selection
	save_map          // no
	keyinput          // no
	hide_colorchips   // no
	quit_map          // no
	selection_delete  // selection
	flip_h            // paste
	flip_v            // paste
	trash
	cc_mode // no
}

const selec_buttons = [Buttons.cancel_button, .copy_button, .save_gate, .create_color_chip,
	.selection_delete, .paste]
const no_mode_buttons = [Buttons.cancel_button, .selection_button, .load_gate, .item_nots,
	.item_diode, .item_crossing, .item_on, .item_wire, .speed, .slow, .pause, .paste, .save_map,
	.keyinput, .hide_colorchips, .cc_mode, .quit_map]
const save_gate_buttons = [Buttons.cancel_button, .confirm_save_gate]
const paste_buttons = [Buttons.cancel_button, .rotate_copy, .load_gate, .flip_h, .flip_v]
const placement_buttons = [Buttons.cancel_button, .item_nots, .item_diode, .item_crossing, .item_on,
	.item_wire]
const edit_buttons = [Buttons.cancel_button, .choose_colorchip, .edit_color, .add_input,
	.copy_settings, .delete_colorchip, .hide_colorchips]

struct ButtonData {
mut:
	pos u32
	img gg.Image
}

struct Palette {
mut:
	junc            gg.Color = gg.Color{0, 0, 0, 255}
	junc_v          gg.Color = gg.Color{255, 217, 46, 255} // vertical line
	junc_h          gg.Color = gg.Color{190, 92, 247, 255} // horiz line
	wire_on         gg.Color = gg.Color{131, 247, 92, 255}
	wire_off        gg.Color = gg.Color{247, 92, 92, 255}
	on              gg.Color = gg.Color{89, 181, 71, 255}
	not             gg.Color = gg.Color{247, 152, 239, 255}
	diode           gg.Color = gg.Color{92, 190, 247, 255}
	background      gg.Color = gg.Color{255, 235, 179, 255}
	place_preview   gg.Color = gg.Color{128, 128, 128, 128}
	copy_preview    gg.Color = gg.Color{255, 255, 255, 128}
	selection_start gg.Color = gg.Color{26, 107, 237, 128}
	selection_end   gg.Color = gg.Color{72, 97, 138, 128}
	selection_box   gg.Color = gg.Color{66, 136, 245, 128}
	input_preview   gg.Color = gg.Color{217, 159, 0, 128}
	selected_ui     gg.Color = gg.Color{128, 128, 128, 64}
	ui_bg           gg.Color = gg.Color{255, 255, 255, 255}
	grid            gg.Color = gg.Color{232, 217, 203, 255}
}

const palette_def = Palette{
	wire_off:   gg.Color{239, 71, 111, 255}
	wire_on:    gg.Color{6, 214, 160, 255}
	background: gg.Color{252, 252, 252, 255}
	diode:      gg.Color{31, 176, 255, 255}
	not:        gg.Color{255, 209, 102, 255}
	on:         gg.Color{37, 248, 157, 255}
	junc:       gg.Color{30, 33, 43, 255}
	junc_v:     gg.Color{255, 220, 92, 255}
	junc_h:     gg.Color{255, 132, 39, 255}
	ui_bg:      gg.Color{234, 235, 235, 255}
}

struct ColorChip {
	x u32
	y u32
	w u32
	h u32
mut:
	colors []gg.Color // colors to show
	inputs []Coo      // the state will be converted to a number (binary) and it will be the index of the shown color
}

const button_map = {
	Buttons.cancel_button: ButtonData{
		pos: 0
	}
	.confirm_save_gate:    ButtonData{
		pos: 1
	}
	.selection_button:     ButtonData{
		pos: 1
	}
	.rotate_copy:          ButtonData{
		pos: 1
	}
	.copy_button:          ButtonData{
		pos: 1
	}
	.choose_colorchip:     ButtonData{
		pos: 1
	}
	.load_gate:            ButtonData{
		pos: 2
	}
	.save_gate:            ButtonData{
		pos: 2
	}
	.edit_color:           ButtonData{
		pos: 2
	}
	.flip_h:               ButtonData{
		pos: 3
	}
	.item_nots:            ButtonData{
		pos: 3
	}
	.create_color_chip:    ButtonData{
		pos: 3
	}
	.add_input:            ButtonData{
		pos: 3
	}
	.flip_v:               ButtonData{
		pos: 4
	}
	.item_diode:           ButtonData{
		pos: 4
	}
	.copy_settings:        ButtonData{
		pos: 4
	}
	.item_crossing:        ButtonData{
		pos: 5
	}
	.delete_colorchip:     ButtonData{
		pos: 5
	}
	.item_on:              ButtonData{
		pos: 6
	}
	.item_wire:            ButtonData{
		pos: 7
	}
	.speed:                ButtonData{
		pos: 8
	}
	.slow:                 ButtonData{
		pos: 9
	}
	.pause:                ButtonData{
		pos: 10
	}
	.paste:                ButtonData{
		pos: 11
	}
	.save_map:             ButtonData{
		pos: 12
	}
	.keyinput:             ButtonData{
		pos: 13
	}
	.hide_colorchips:      ButtonData{
		pos: 14
	}
	.cc_mode:              ButtonData{
		pos: 15
	}
	.quit_map:             ButtonData{
		pos: 16
	}
	.selection_delete:     ButtonData{
		pos: 7
	}
	.trash:                ButtonData{}
}

struct App {
mut:
	ctx               &gg.Context = unsafe { nil }
	e                 &gg.Event   = &gg.Event{}
	s                 gg.Size // screen size
	ui                f32 = 1.0 // ui scale, factor by which all ui is multiplied
	draw_count        int = 1
	draw_step         int = 20000 // number of draw calls before .end( passthru
	tile_size         int = 30
	text_input        string // holds what the user typed
	colorchips_hidden bool   // if colorchips are hidden
	mouse_down        bool
	mouse_map_x       u32
	mouse_map_y       u32
	mouse_action      string
	scroll_pos        f32
	debug_mode        bool
	// main menu
	main_menu  bool
	solo_img   gg.Image
	banner_img gg.Image
	// solo menu TODO: display map info of the hovered map (size bits, nb of hours played, gates placed... fun stuff)
	solo_menu      bool
	map_delete_nb  int = -1
	map_names_list []string // without folder name
	// edit mode -> edit colorchips
	edit_mode                 bool
	editmenu_nb_color_by_row  int = 20
	editmenu_selected_color   int // TODO: show coords of input
	editmenu_nb_inputs_by_row int = 16
	editmenu_hold             int
	delete_colorchip_submode  bool
	create_colorchip_submode  bool // select start and end of the new colorchip
	choose_colorchip_submode  bool // select a colorchip to edit
	copy_settings_submode     bool
	add_input_submode         bool // to add an input to a colorchip
	edit_color_submode        bool // edit colors of a colorchip
	selected_colorchip        int = -1 // index of the selected colorchip
	// test mode
	test_mode bool
	// camera moving -> default mode
	cam_x     f64 = default_camera_pos_x
	cam_y     f64 = default_camera_pos_y
	move_down bool
	click_x   f32 // Holds the position of the click (start point of the camera movement)
	click_y   f32
	drag_x    f32 // Holds the actual position of the click (to be able to render the moved map even if the camera movement is not yet finished (by releasing the mouse))
	drag_y    f32
	// placement mode
	placement_mode bool
	place_down     bool
	place_start_x  u32 = u32(-1)
	place_start_y  u32
	place_end_x    u32 // Only used for preview
	place_end_y    u32
	// selection mode (left click: starting pos of selection, right click: ending position of selection)
	selection_mode bool
	select_start_x u32 = u32(-1)
	select_start_y u32
	select_end_x   u32
	select_end_y   u32
	// paste mode
	paste_mode bool
	// load gate mode
	load_gate_mode bool
	gate_name_list []string // without folder name
	// save gate mode
	save_gate_mode bool
	// keyboard input (force state of a gate to ON) mode
	keyinput_mode bool
	key_pos       map[u8][]Coo // `n` -> [[0, 3], [32, 53]] : will force the state to ON at x:0 y:3 and x:32 y:53 if the key is pressed
	tmp_pos_x     u32 = u32(-1)
	tmp_pos_y     u32 = u32(-1)
	// UI on the left border
	buttons       map[Buttons]ButtonData = button_map.clone()
	log           []string
	log_border    gg.Color
	log_timer     int
	not_on_img    gg.Image
	not_off_img   gg.Image
	diode_on_img  gg.Image
	diode_off_img gg.Image
	wire_on_img   gg.Image
	wire_off_img  gg.Image
	junc_img      gg.Image
	on_img        gg.Image
	not_on_coo    []f32
	not_off_coo   []f32
	diode_on_coo  []f32
	diode_off_coo []f32
	wire_on_coo   []f32
	wire_off_coo  []f32
	junc_coo      []f32
	on_coo        []f32

	// logic
	map               []Chunk
	cl_thread         thread
	map_name          string // to fill when loading a map
	comp_running      bool   // is a map loaded and running
	pause             bool   // is the map updating
	nb_updates        i32 = 5 // number of updates per second
	avg_update_time   f64 // nanosecs
	todo              []TodoInfo
	selected_item     Elem
	selected_ori      u64 = north
	copied            []PlaceInstruction
	actual_state      i32 // indicate which list is the old state list and which is the actual one, 0 for the first, 1 for the second
	nots              []Nots    = nots_array_default.clone() // to start the rid at 1
	n_states          [2][]bool = [[false], [false]]! // the old state and the actual state list
	dead_nots         []u64 // stores the rid of the dead nots (with invalid_coo, the ones that were removed)
	dead_nots_lower   i64   // marks the beggining of the valid dead nots (invalids not removed from the array)
	diodes            []Diode   = diode_array_default.clone()
	d_states          [2][]bool = [[false], [false]]!
	dead_diodes       []u64
	dead_diodes_lower i64
	wires             []Wire    = wire_array_default.clone()
	w_states          [2][]bool = [[false], [false]]!
	dead_wires        []u64
	dead_wires_lower  i64
	forced_states     []Coo       // forced to ON state by a keyboard input
	colorchips        []ColorChip // screens
	palette           Palette = palette_def // TODO: edit palette and save palette
	comp_alive        bool
	chunk_cache       map[u64]i32 // x u32 y u32 -> index of app.map
}

// graphics

fn main() {
	mut app := &App{}
	app.main_menu = true
	app.log('Start: ${time.now()}', .info)
	app.ctx = gg.new_context(
		create_window: true
		window_title:  'Not Gates'
		user_data:     app
		init_fn:       on_init
		frame_fn:      on_frame
		event_fn:      on_event
		sample_count:  0
		bg_color:      app.palette.background
		font_path:     font_path
	)
	app.ctx.run()
}

fn on_init(mut app App) {
	app.init_graphics() or { app.log_quit('${err}') }
}

fn (mut app App) init_graphics() ! {
	// lancement du programme/de la fenêtre
	unsafe {
		app.buttons[.cancel_button].img = app.ctx.create_image(sprites_path + 'cancel_button.png')!
		app.buttons[.confirm_save_gate].img = app.ctx.create_image(sprites_path +
			'confirm_save_gate.png')!
		app.buttons[.selection_button].img = app.ctx.create_image(sprites_path +
			'selection_button.png')!
		app.buttons[.rotate_copy].img = app.ctx.create_image(sprites_path + 'rotate_copy.png')!
		app.buttons[.copy_button].img = app.ctx.create_image(sprites_path + 'copy_button.png')!
		app.buttons[.choose_colorchip].img = app.ctx.create_image(sprites_path +
			'choose_colorchip.png')!
		app.buttons[.load_gate].img = app.ctx.create_image(sprites_path + 'load_gate.png')!
		app.buttons[.save_gate].img = app.ctx.create_image(sprites_path + 'save_gate.png')!
		app.buttons[.edit_color].img = app.ctx.create_image(sprites_path + 'edit_color.png')!
		app.buttons[.item_nots].img = app.ctx.create_image(sprites_path + 'not_off.png')!
		app.buttons[.create_color_chip].img = app.ctx.create_image(sprites_path +
			'create_color_chip.png')!
		app.buttons[.add_input].img = app.ctx.create_image(sprites_path + 'add_input.png')!
		app.buttons[.item_diode].img = app.ctx.create_image(sprites_path + 'diode_off.png')!
		app.buttons[.copy_settings].img = app.ctx.create_image(sprites_path + 'steal_settings.png')!
		app.buttons[.item_crossing].img = app.ctx.create_image(sprites_path + 'junction.png')!
		app.buttons[.delete_colorchip].img = app.ctx.create_image(sprites_path +
			'delete_colorchip.png')!
		app.buttons[.item_on].img = app.ctx.create_image(sprites_path + 'on.png')!
		app.buttons[.item_wire].img = app.ctx.create_image(sprites_path + 'wire_on.png')!
		app.buttons[.speed].img = app.ctx.create_image(sprites_path + 'speed.png')!
		app.buttons[.slow].img = app.ctx.create_image(sprites_path + 'slow.png')!
		app.buttons[.pause].img = app.ctx.create_image(sprites_path + 'pause.png')!
		app.buttons[.paste].img = app.ctx.create_image(sprites_path + 'paste.png')!
		app.buttons[.save_map].img = app.ctx.create_image(sprites_path + 'save_map.png')!
		app.buttons[.keyinput].img = app.ctx.create_image(sprites_path + 'keyinput.png')!
		app.buttons[.hide_colorchips].img = app.ctx.create_image(sprites_path +
			'hide_colorchips.png')!
		app.buttons[.quit_map].img = app.ctx.create_image(sprites_path + 'quit_map.png')!
		app.buttons[.cc_mode].img = app.ctx.create_image(sprites_path + 'edit_color.png')!
		app.buttons[.flip_h].img = app.ctx.create_image(sprites_path + 'flip_h.png')!
		app.buttons[.flip_v].img = app.ctx.create_image(sprites_path + 'flip_v.png')!
		app.buttons[.selection_delete].img = app.ctx.create_image(sprites_path +
			'selection_delete.png')!
		app.buttons[.trash].img = app.ctx.create_image(sprites_path + 'trash.png')!
	}
	app.not_on_img = app.ctx.create_image(sprites_path + 'not_on.png')!
	app.not_off_img = app.ctx.create_image(sprites_path + 'not_off.png')!
	app.diode_on_img = app.ctx.create_image(sprites_path + 'diode_on.png')!
	app.diode_off_img = app.ctx.create_image(sprites_path + 'diode_off.png')!
	app.wire_on_img = app.ctx.create_image(sprites_path + 'wire_on.png')!
	app.wire_off_img = app.ctx.create_image(sprites_path + 'wire_off.png')!
	app.junc_img = app.ctx.create_image(sprites_path + 'junction.png')!
	app.on_img = app.ctx.create_image(sprites_path + 'on.png')!
	app.banner_img = app.ctx.create_image(sprites_path + 'banner.png')!
	app.solo_img = app.ctx.create_image(sprites_path + 'play.png')!
	app.load_palette()
}

fn toml_palette_color(color string, doc toml.Doc) gg.Color {
	a := doc.value(color).array()
	return gg.Color{u8(a[0].u64()), u8(a[1].u64()), u8(a[2].u64()), u8(a[3].u64())}
}

fn (mut app App) load_palette() {
	doc := toml.parse_file(palette_path) or {
		app.log('Loading palette: ${err}', .err)
		return
	}
	app.palette.background = toml_palette_color('background', doc)
	app.palette.place_preview = toml_palette_color('place_preview', doc)
	app.palette.copy_preview = toml_palette_color('copy_preview', doc)
	app.palette.selection_start = toml_palette_color('selection_start', doc)
	app.palette.selection_end = toml_palette_color('selection_end', doc)
	app.palette.selection_box = toml_palette_color('selection_box', doc)
	app.palette.input_preview = toml_palette_color('input_preview', doc)
	app.palette.selected_ui = toml_palette_color('selected_ui', doc)
	app.palette.ui_bg = toml_palette_color('ui_bg', doc)
	app.palette.grid = toml_palette_color('grid', doc)
}

fn (app App) scale_sprite(a [][]f32) [][]f32 {
	mut new_a := [][]f32{len: a.len, init: []f32{len: a[0].len}}
	for i, dir_a in a {
		for j, coo in dir_a {
			new_a[i][j] = coo * app.tile_size
		}
	}
	return new_a
}

fn on_frame(mut app App) {
	app.mouse_map_x = u32(app.cam_x + app.ctx.mouse_pos_x / app.tile_size)
	app.mouse_map_y = u32(app.cam_y + app.ctx.mouse_pos_y / app.tile_size)
	app.draw_count = 1
	app.s = app.ctx.window_size()
	app.ui = f32(app.s.height) / f32(default_win_height)
	// Draw
	app.ctx.begin()
	app.ctx.draw_rect_filled(0, 0, app.s.width, app.s.height, app.palette.background)
	mut ui_log_cfg := gg.TextCfg{
		size:  int(log_cfg.size * app.ui)
		color: log_cfg.color
	}
	if app.comp_running {
		if app.selected_colorchip < -1 || app.selected_colorchip > app.colorchips.len {
			app.selected_colorchip = -1
		}
		if app.edit_mode && app.mouse_down {
			if app.move_down {
			} else if app.e.mouse_x < app.ui * ui_width {
			} else {
				if app.edit_color_submode && app.selected_colorchip != -1
					&& (app.editmenu_hold >= 20 || app.editmenu_hold % 5 == 0) {
					app.check_and_change_color_cc(app.e.mouse_x, app.e.mouse_y)
				}
				app.editmenu_hold += 1
			}
		}
		app.draw_map()

		if !app.colorchips_hidden {
			virt_cam_x := app.cam_x - (app.drag_x - app.click_x) / app.tile_size
			virt_cam_y := app.cam_y - (app.drag_y - app.click_y) / app.tile_size
			for j, cc in app.colorchips {
				pos_x := f32((f64(cc.x) - virt_cam_x) * app.tile_size)
				pos_y := f32((f64(cc.y) - virt_cam_y) * app.tile_size)
				w := f32(int(cc.w) * app.tile_size)
				h := f32(int(cc.h) * app.tile_size)
				mut color_i := 0
				mut chunk_i := app.get_chunkmap_idx_at_coords(cc.x, cc.y)
				mut chunkmap := &app.map[chunk_i].id_map
				mut xmap := cc.x & chunk_bitmask
				mut ymap := cc.y & chunk_bitmask
				mut id := unsafe { chunkmap[xmap * chunk_size + ymap] }
				mut last_cm_x := cc.x
				mut last_cm_y := cc.y
				for i, coo in cc.inputs {
					if check_change_chunkmap(last_cm_x, last_cm_y, coo.x, coo.y) {
						last_cm_x = cc.x
						last_cm_y = cc.y
						chunk_i = app.get_chunkmap_idx_at_coords(coo.x, coo.y)
					}
					chunkmap = &app.map[chunk_i].id_map
					xmap = coo.x & chunk_bitmask
					ymap = coo.y & chunk_bitmask
					id = unsafe { chunkmap[xmap * chunk_size + ymap] }
					if id == elem_crossing_bits || id == empty_id {
						continue
					}
					if id & elem_type_mask == elem_on_bits || id & on_bits != 0 {
						color_i += int(pow(2, i))
					}
				}
				app.ctx.draw_rect_filled(pos_x, pos_y, w, h, cc.colors[color_i])
				if app.edit_mode && j == app.selected_colorchip {
					app.ctx.draw_circle_filled(pos_x, pos_y, selected_cc_circle_r, gg.red)
				}
			}
		}

		// placing preview
		if app.placement_mode && app.place_start_x != u32(-1) { // did not hide the check to be able to see when it is happening
			app.draw_placing_preview()
		}
		if app.selection_mode {
			app.draw_selection_box()
		}
		if app.keyinput_mode {
			app.draw_input_buttons()
		}
		if app.paste_mode {
			app.draw_paste_preview()
		}
		app.draw_ingame_ui_buttons()

		compute_info := '${app.nb_updates}/s = ${int(time.second / app.nb_updates) / 1_000_000}ms/update (required:${app.avg_update_time / 1_000_000.0:.2f}ms)'
		coords_info := 'x:${i64(app.cam_x)} y:${i64(app.cam_y)}'
		info_text_x := int((ui_width + 10) * app.ui)
		app.ctx.draw_text(info_text_x, int(info_text_off * app.ui), app.map_name, ui_log_cfg)
		app.ctx.draw_text(info_text_x, int((info_text_off + info_text_spacing) * app.ui),
			compute_info, ui_log_cfg)
		app.ctx.draw_text(info_text_x, int((info_text_off + 2 * info_text_spacing) * app.ui),
			coords_info, ui_log_cfg)
		app.ctx.draw_text(info_text_x, app.s.height - int(info_text_spacing * app.ui),
			app.mouse_action, ui_log_cfg)

		if app.save_gate_mode {
			input_x := (ui_width + input_box_off) * app.ui
			box_y := input_box_off * app.ui
			box_w := input_box_w * app.ui
			box_h := input_box_h * app.ui
			text_x := int((ui_width + input_text_off_x) * app.ui)
			text_y := int(box_y + input_text_off_y * app.ui)
			app.ctx.draw_rect_filled(input_x, box_y, box_w, box_h, app.palette.ui_bg)
			app.ctx.draw_text(text_x, text_y, 'Save gate: ${app.text_input}', ui_log_cfg)
		}
		if app.load_gate_mode {
			input_x := (ui_width + input_box_off) * app.ui
			box_y := input_box_off * app.ui
			box_w := input_box_w * app.ui
			box_h := input_box_h * app.ui
			text_x := int((ui_width + input_text_off_x) * app.ui)
			text_y := int(box_y + input_text_off_y * app.ui)
			app.ctx.draw_rect_filled(input_x, box_y, box_w, box_h, app.palette.ui_bg)
			app.ctx.draw_text(text_x, text_y, 'Load gate: ${app.text_input}', ui_log_cfg)
			// search results

			if !os.exists(gates_path) {
				if !os.exists(player_data_path) {
					os.mkdir(player_data_path) or {
						app.log('Cannot create ${player_data_path}, ${err}', .err)
						return
					}
				}
				os.mkdir(gates_path) or {
					app.log('Cannot create ${gates_path}, ${err}', .err)
					return
				}
			}
			app.gate_name_list = os.ls(gates_path) or {
				app.log('cannot list files in ${gates_path}, ${err}', .err)
				[]string{}
			}
			x := (ui_width + gate_x_ofst) * app.ui
			total_h := (gate_top_spacing + gate_h) * app.ui
			w := (ui_width + gate_x_ofst + gate_w) * app.ui
			for pos, name in app.gate_name_list.filter(it.contains(app.text_input)) { // the maps are filtered with the search field
				y := pos * total_h + gate_y_offset * app.ui
				y_text := int(y + gate_text_off_x * app.ui)
				app.ctx.draw_rect_filled(x, y, w, gate_h * app.ui, app.palette.ui_bg)
				app.ctx.draw_text(int(x), y_text, name, ui_log_cfg)
			}
		}
		if app.edit_mode {
			if app.edit_color_submode && app.selected_colorchip != -1 {
				last_rel_input_y := (app.colorchips[app.selected_colorchip].inputs.len - 1) / app.editmenu_nb_inputs_by_row * app.ui * editmenu_inputsize
				x_bg := app.ui * (editmenu_offset_x + editmenu_offset_colors_x / 2)
				y_bg := app.ui * editmenu_offset_y
				h_bg := app.ui * (editmenu_offset_y + editmenu_offset_colors_y) +
					(app.colorchips[app.selected_colorchip].colors.len / app.editmenu_nb_color_by_row +
					1) * app.ui * editmenu_colorsize + last_rel_input_y - y_bg + editmenu_colorsize
				w_bg := app.ui * 1000
				app.ctx.draw_rect_filled(x_bg, y_bg, w_bg, h_bg, app.palette.ui_bg)
				for i in 0 .. app.colorchips[app.selected_colorchip].inputs.len {
					x := app.ui * (editmenu_offset_inputs_x + editmenu_offset_x) +
						i % app.editmenu_nb_inputs_by_row * app.ui * (editmenu_inputsize +
						editmenu_input_x_space)
					y := app.ui * (editmenu_offset_inputs_y + editmenu_offset_y) +
						i / app.editmenu_nb_inputs_by_row * app.ui * editmenu_inputsize
					size := app.ui * editmenu_inputsize
					app.ctx.draw_square_filled(x, y, size, app.palette.input_preview)
					app.ctx.draw_text(int(x), int(y), i.str(), ui_log_cfg)
				}

				for i, color in app.colorchips[app.selected_colorchip].colors {
					x := app.ui * (editmenu_offset_x + editmenu_offset_colors_x) +
						i % app.editmenu_nb_color_by_row * app.ui * editmenu_colorsize
					y := app.ui * (editmenu_offset_y + editmenu_offset_colors_y) +
						i / app.editmenu_nb_color_by_row * app.ui * editmenu_colorsize +
						last_rel_input_y
					size := app.ui * editmenu_colorsize
					app.ctx.draw_square_filled(x, y, size, color)
				}
				// Selected color
				if app.editmenu_selected_color >= 0
					&& app.editmenu_selected_color < app.colorchips[app.selected_colorchip].colors.len {
					x := app.ui * (editmenu_offset_x + editmenu_offset_colors_x) +
						app.editmenu_selected_color % app.editmenu_nb_color_by_row * app.ui * editmenu_colorsize
					y := app.ui * (editmenu_offset_y + editmenu_offset_colors_y) +
						app.editmenu_selected_color / app.editmenu_nb_color_by_row * app.ui * editmenu_colorsize +
						last_rel_input_y
					size := app.ui * editmenu_colorsize
					border := app.ui * editmenu_colorborder
					app.ctx.draw_square_filled(x - border, y - border, size + 2 * border,
						app.colorchips[app.selected_colorchip].colors[app.editmenu_selected_color])
					app.ctx.draw_square_empty(x - border, y - border, size + 2 * border,
						gg.rgb(39, 188, 235))
				}

				// rgb picker
				rgb_y := app.ui * (editmenu_rgb_y + editmenu_offset_y)
				rgb_h := app.ui * editmenu_rgb_h
				rgb_w := app.ui * editmenu_rgb_w
				r_x := app.ui * (editmenu_r_x + editmenu_offset_x)
				g_x := app.ui * (editmenu_g_x + editmenu_offset_x)
				b_x := app.ui * (editmenu_b_x + editmenu_offset_x)
				app.ctx.draw_rect_filled(r_x, rgb_y, rgb_w, rgb_h, gg.red)
				app.ctx.draw_rect_filled(g_x, rgb_y, rgb_w, rgb_h, gg.green)
				app.ctx.draw_rect_filled(b_x, rgb_y, rgb_w, rgb_h, gg.Color{64, 128, 255, 255})
				selected_color := app.colorchips[app.selected_colorchip].colors[app.editmenu_selected_color]
				app.ctx.draw_text(int(r_x), int(rgb_y), selected_color.r.str(), ui_log_cfg)
				app.ctx.draw_text(int(g_x), int(rgb_y), selected_color.g.str(), ui_log_cfg)
				app.ctx.draw_text(int(b_x), int(rgb_y), selected_color.b.str(), ui_log_cfg)
			}
			if app.selected_colorchip != -1 {
				virt_cam_x := app.cam_x - (app.drag_x - app.click_x) / app.tile_size
				virt_cam_y := app.cam_y - (app.drag_y - app.click_y) / app.tile_size
				half := app.tile_size / 2
				quar := half / 2
				for i, inp in app.colorchips[app.selected_colorchip].inputs {
					pos_x := f32((f64(inp.x) - virt_cam_x) * app.tile_size)
					pos_y := f32((f64(inp.y) - virt_cam_y) * app.tile_size)
					// check if input button is selected
					x := app.ui * (editmenu_offset_inputs_x + editmenu_offset_x) +
						i % app.editmenu_nb_inputs_by_row * app.ui * (editmenu_inputsize +
						editmenu_input_x_space)
					y := app.ui * (editmenu_offset_inputs_y + editmenu_offset_y) +
						i / app.editmenu_nb_inputs_by_row * app.ui * editmenu_inputsize
					if app.edit_color_submode && app.e.mouse_x >= x
						&& app.e.mouse_x < x + app.ui * editmenu_inputsize && app.e.mouse_y >= y
						&& app.e.mouse_y < y + app.ui * editmenu_inputsize {
						app.ctx.draw_square_filled(pos_x, pos_y, app.tile_size, app.palette.input_preview)
					} else {
						app.ctx.draw_square_filled(pos_x + quar, pos_y + quar, half, app.palette.input_preview)
					}
					app.ctx.draw_text(int(pos_x + half - ui_log_cfg.size / 4), int(pos_y + half - ui_log_cfg.size / 2),
						i.str(), ui_log_cfg)
				}
			}
		}
		if app.debug_mode {
			x := app.mouse_map_x
			y := app.mouse_map_y
			mut chunk_i := app.get_chunkmap_idx_at_coords(x, y)
			mut chunkmap := &app.map[chunk_i].id_map
			x_map := x & chunk_bitmask
			y_map := y & chunk_bitmask
			id := unsafe { chunkmap[x_map * chunk_size + y_map] }
			rid := id & rid_mask
			tile_mid := app.tile_size / 2
			if id == 0x0 { // map empty
			} else if id == elem_crossing_bits { // same bits as wires so need to be separated
			} else {
				match id & elem_type_mask {
					elem_wire_bits {
						w := app.wires[rid]
						// println('Wire inps: ${w.inps.map('${it:064b}')} outs: ${w.outs.map('${it:064b}')} cable_coords: ${w.cable_coords} cable_chunk_i: ${w.cable_chunk_i}')
						for inp in w.inps {
							info := app.get_info(inp)
							for c in info.coos {
								inp_x := f32((f64(c.x) - app.cam_x) * app.tile_size) + tile_mid
								inp_y := f32((f64(c.y) - app.cam_y) * app.tile_size) + tile_mid
								app.ctx.draw_circle_empty(inp_x, inp_y, 10, gg.yellow)
							}
						}
						for out in w.outs {
							info := app.get_info(out)
							for c in info.coos {
								inp_x := f32((f64(c.x) - app.cam_x) * app.tile_size) + tile_mid
								inp_y := f32((f64(c.y) - app.cam_y) * app.tile_size) + tile_mid
								app.ctx.draw_circle_empty(inp_x, inp_y, 10, gg.purple)
							}
						}
					}
					elem_not_bits {
						n := app.nots[rid]
						pos_x := f32((f64(x) - app.cam_x) * app.tile_size) + tile_mid
						pos_y := f32((f64(y) - app.cam_y) * app.tile_size) + tile_mid
						if n.x == invalid_coo {
							app.ctx.draw_circle_empty(pos_x, pos_y, 20, gg.red)
						}
						app.ctx.draw_circle_empty(pos_x, pos_y, 10, gg.blue)
						// input info
						info := app.get_info(n.inp)
						if info.dead {
							app.ctx.draw_circle_filled(app.e.mouse_x, app.e.mouse_y, 10,
								gg.black)
						} else {
							app.ctx.draw_circle_empty(app.e.mouse_x, app.e.mouse_y, 10,
								gg.white)
						}
						for c in info.coos {
							inp_x := f32((f64(c.x) - app.cam_x) * app.tile_size) + tile_mid
							inp_y := f32((f64(c.y) - app.cam_y) * app.tile_size) + tile_mid
							app.ctx.draw_circle_empty(inp_x, inp_y, 10, gg.yellow)
						}
					}
					elem_diode_bits {
						d := app.diodes[rid]
						pos_x := f32((f64(x) - app.cam_x) * app.tile_size) + tile_mid
						pos_y := f32((f64(y) - app.cam_y) * app.tile_size) + tile_mid
						if d.x == invalid_coo {
							app.ctx.draw_circle_empty(pos_x, pos_y, 20, gg.red)
						}
						app.ctx.draw_circle_empty(pos_x, pos_y, 10, gg.blue)
						// input info
						info := app.get_info(d.inp)
						if info.dead {
							app.ctx.draw_circle_filled(app.e.mouse_x, app.e.mouse_y, 10,
								gg.black)
						} else {
							app.ctx.draw_circle_empty(app.e.mouse_x, app.e.mouse_y, 10,
								gg.white)
						}
						for c in info.coos {
							inp_x := f32((f64(c.x) - app.cam_x) * app.tile_size) + tile_mid
							inp_y := f32((f64(c.y) - app.cam_y) * app.tile_size) + tile_mid
							app.ctx.draw_circle_empty(inp_x, inp_y, 10, gg.yellow)
						}
					}
					elem_on_bits {}
					else {
						app.log_quit('${@LOCATION} should not get into this else')
					}
				}
			}
		}
	} else if app.main_menu {
		app.ctx.draw_image(0, 0, default_win_width * app.ui, default_win_height * app.ui,
			app.banner_img)
		app.ctx.draw_image(button_solo_x * app.ui, button_solo_y * app.ui, button_solo_w * app.ui,
			button_solo_h * app.ui, app.solo_img)
		app.ctx.draw_image(btn_quit_ofst * app.ui, btn_quit_y * app.ui, button_quit_size * app.ui,
			button_quit_size * app.ui, unsafe { app.buttons[.quit_map].img })
	} else if app.solo_menu {
		for i, m in app.map_names_list.filter(it.contains(app.text_input)) { // the maps are filtered with the search field
			y := (maps_y_offset + maps_top_spacing) * (i + 1) * app.ui
			app.ctx.draw_rect_filled(maps_x_offset * app.ui, y, maps_w * app.ui, maps_h * app.ui,
				app.palette.ui_bg)
			app.ctx.draw_text(int(maps_x_offset * app.ui), int(y), m, ui_log_cfg)
			end_x := (maps_x_offset + maps_w) * app.ui
			h := maps_h * app.ui
			if i != app.map_delete_nb {
				app.ctx.draw_image(end_x, y, h, h, unsafe { app.buttons[.trash].img })
			} else {
				app.ctx.draw_image(end_x + h, y, h, h, unsafe { app.buttons[.trash].img })
			}
		}
		new_x := button_new_map_x * app.ui
		new_y := button_new_map_y * app.ui
		new_size := button_new_map_size * app.ui
		app.ctx.draw_image(new_x, new_y, new_size, new_size, unsafe { app.buttons[.confirm_save_gate].img })
		back_x := btn_back_x * app.ui
		back_y := btn_back_y * app.ui
		back_s := btn_back_s * app.ui
		app.ctx.draw_image(back_x, back_y, back_s, back_s, unsafe { app.buttons[.quit_map].img })
		text_x := int(text_field_x * app.ui)
		text_y := int((text_field_y + button_new_map_size / 2 - f32(ui_log_cfg.size) / 2) * app.ui)
		text_input := if app.text_input != '' {
			app.text_input
		} else {
			'[enter a map name]'
		}
		app.ctx.draw_text(text_x, text_y, 'Create/search map: ' + text_input, ui_log_cfg)
	} else {
		app.disable_all_ingame_modes()
		app.ctx.draw_square_filled(0, 0, 10, gg.Color{255, 0, 0, 255})
		app.log('Not implemented on_frame UI', .err)
	}
	if app.log_timer > 0 {
		border := log_border * app.ui
		width := log_width * app.ui
		interline_spacing := log_interline_spacing * app.ui
		h := app.log.len * (ui_log_cfg.size + interline_spacing)
		rect_x := app.s.width - width - log_border
		rect_y := app.s.height - h - border
		bor_x := rect_x - border
		bor_y := rect_y - border
		bor_w := width + 2 * border
		bor_h := h + 2 * border
		// colored border rect
		app.ctx.draw_rect_filled(bor_x, bor_y, bor_w, bor_h, app.log_border)
		app.ctx.draw_rect_filled(rect_x, rect_y, width, h, gg.white)
		for i, l in app.log {
			ly := int(rect_y + i * (interline_spacing + ui_log_cfg.size))
			app.ctx.draw_text(int(rect_x), ly, l, ui_log_cfg)
		}
		app.log_timer -= 1
	}
	app.ctx.end(how: .passthru)
}

struct DebugInfo {
mut:
	id   u64
	coos []Coo
	dead bool
}

fn (mut app App) get_info(id u64) DebugInfo {
	mut info := DebugInfo{
		id: id
	}
	rid := id & rid_mask
	if id == 0x0 { // map empty
	} else if id == elem_crossing_bits { // same bits as wires so need to be separated
	} else {
		match id & elem_type_mask {
			elem_wire_bits {
				w := app.wires[rid]
				info.dead = w.cable_coords[0].x == invalid_coo
				info.coos = w.cable_coords.clone()
			}
			elem_not_bits {
				n := app.nots[rid]
				info.dead = n.x == invalid_coo
				info.coos << Coo{n.x, n.y}
			}
			elem_diode_bits {
				d := app.diodes[rid]
				info.dead = d.x == invalid_coo
				info.coos << Coo{d.x, d.y}
			}
			elem_on_bits {}
			else {
				app.log_quit('${@LOCATION} should not get into this else')
			}
		}
	}
	return info
}

fn (mut app App) draw_ingame_ui_buttons() {
	base_x := button_left_padding * app.ui
	base_y := button_top_padding * app.ui
	size := button_size * app.ui
	y_factor := base_y + size
	app.ctx.draw_rect_filled(0, 0, app.ui * ui_width, app.ui * 1400.0, app.palette.ui_bg)
	app.ctx.draw_square_filled(base_x, base_y, size, default_button_color) // cancel_button
	unsafe {
		if app.selection_mode {
			for button in selec_buttons {
				app.ctx.draw_image(base_x, app.buttons[button].pos * y_factor + base_y,
					size, size, app.buttons[button].img)
			}
		} else if app.load_gate_mode {
			app.ctx.draw_image(base_x, app.buttons[.cancel_button].pos * y_factor + base_y,
				size, size, app.buttons[.cancel_button].img)
		} else if app.paste_mode {
			for button in paste_buttons {
				app.ctx.draw_image(base_x, app.buttons[button].pos * y_factor + base_y,
					size, size, app.buttons[button].img)
			}
		} else if app.save_gate_mode {
			for button in save_gate_buttons {
				app.ctx.draw_image(base_x, app.buttons[button].pos * y_factor + base_y,
					size, size, app.buttons[button].img)
			}
		} else if app.placement_mode {
			for button in placement_buttons {
				y := app.buttons[button].pos * y_factor + base_y
				app.ctx.draw_image(base_x, y, size, size, app.buttons[button].img)
				if button == .item_nots && app.selected_item == .not {
					app.ctx.draw_square_filled(base_x, y, size, app.palette.selected_ui)
				} else if button == .item_diode && app.selected_item == .diode {
					app.ctx.draw_square_filled(base_x, y, size, app.palette.selected_ui)
				} else if button == .item_on && app.selected_item == .on {
					app.ctx.draw_square_filled(base_x, y, size, app.palette.selected_ui)
				} else if button == .item_crossing && app.selected_item == .crossing {
					app.ctx.draw_square_filled(base_x, y, size, app.palette.selected_ui)
				} else if button == .item_wire && app.selected_item == .wire {
					app.ctx.draw_square_filled(base_x, y, size, app.palette.selected_ui)
				}
			}
		} else if app.edit_mode {
			for button in edit_buttons {
				y := app.buttons[button].pos * y_factor + base_y
				app.ctx.draw_image(base_x, y, size, size, app.buttons[button].img)
				if button == .choose_colorchip && app.choose_colorchip_submode {
					app.ctx.draw_square_filled(base_x, y, size, app.palette.selected_ui)
				} else if button == .edit_color && app.edit_color_submode {
					app.ctx.draw_square_filled(base_x, y, size, app.palette.selected_ui)
				} else if button == .add_input && app.add_input_submode {
					app.ctx.draw_square_filled(base_x, y, size, app.palette.selected_ui)
				} else if button == .copy_settings && app.copy_settings_submode {
					app.ctx.draw_square_filled(base_x, y, size, app.palette.selected_ui)
				} else if button == .delete_colorchip && app.delete_colorchip_submode {
					app.ctx.draw_square_filled(base_x, y, size, app.palette.selected_ui)
				}
			}
		} else { // no mode
			for button in no_mode_buttons {
				y := app.buttons[button].pos * y_factor + base_y
				app.ctx.draw_image(base_x, y, size, size, app.buttons[button].img)
				if button == .pause && app.pause {
					app.ctx.draw_square_filled(base_x, y, size, app.palette.selected_ui)
				}
			}
		}
	}
}

// keyboard inputs locations
fn (mut app App) draw_input_buttons() {
	virt_cam_x := app.cam_x - (app.drag_x - app.click_x) / app.tile_size
	virt_cam_y := app.cam_y - (app.drag_y - app.click_y) / app.tile_size
	half := app.tile_size / 2
	quarter := half / 2
	mut ui_log_cfg := gg.TextCfg{
		size:  int(log_cfg.size * app.ui)
		color: log_cfg.color
	}
	half_size := ui_log_cfg.size / 2
	quar_size := half_size / 2
	for c, positions in app.key_pos {
		for pos in positions {
			pos_x := f32((pos.x - virt_cam_x) * app.tile_size)
			pos_y := f32((pos.y - virt_cam_y) * app.tile_size)
			app.ctx.draw_square_filled(pos_x + quarter, pos_y + quarter, half, app.palette.input_preview)
			app.ctx.draw_text(int(pos_x + half - quar_size), int(pos_y + half - half_size),
				c.ascii_str(), ui_log_cfg)
		}
	}
	if app.tmp_pos_x != u32(-1) && app.tmp_pos_y != u32(-1) {
		pos_x := f32((app.tmp_pos_x - virt_cam_x) * app.tile_size)
		pos_y := f32((app.tmp_pos_y - virt_cam_y) * app.tile_size)
		app.ctx.draw_square_filled(pos_x, pos_y, app.tile_size, app.palette.input_preview)
	}
}

fn (mut app App) draw_placing_preview() {
	virt_cam_x := app.cam_x - (app.drag_x - app.click_x) / app.tile_size
	virt_cam_y := app.cam_y - (app.drag_y - app.click_y) / app.tile_size
	x_start, x_end := if app.place_start_x > app.place_end_x {
		app.place_end_x, app.place_start_x
	} else {
		app.place_start_x, app.place_end_x
	}
	y_start, y_end := if app.place_start_y > app.place_end_y {
		app.place_end_y, app.place_start_y
	} else {
		app.place_start_y, app.place_end_y
	}
	for x in x_start .. x_end + 1 {
		for y in y_start .. y_end + 1 {
			pos_x := f32((f64(x) - virt_cam_x) * app.tile_size)
			pos_y := f32((f64(y) - virt_cam_y) * app.tile_size)
			app.ctx.draw_square_filled(pos_x, pos_y, app.tile_size, app.palette.place_preview)
			app.draw_count += 1
		}
	}
}

fn (mut app App) draw_paste_preview() {
	app.not_on_coo.clear()
	app.not_off_coo.clear()
	app.diode_on_coo.clear()
	app.diode_off_coo.clear()
	app.wire_on_coo.clear()
	app.wire_off_coo.clear()
	app.junc_coo.clear()
	app.on_coo.clear()

	virt_cam_x := app.cam_x - (app.drag_x - app.click_x) / app.tile_size
	virt_cam_y := app.cam_y - (app.drag_y - app.click_y) / app.tile_size
	mouse_map_x := u32(virt_cam_x + app.e.mouse_x / app.tile_size)
	mouse_map_y := u32(virt_cam_y + app.e.mouse_y / app.tile_size)
	m_x := f32((f64(mouse_map_x) - virt_cam_x) * app.tile_size)
	m_y := f32((f64(mouse_map_y) - virt_cam_y) * app.tile_size)
	mut max_x := m_x
	mut max_y := m_y
	for pi in app.copied {
		pos_x := f32((f64(pi.rel_x) + f64(mouse_map_x) - virt_cam_x) * app.tile_size)
		pos_y := f32((f64(pi.rel_y) + f64(mouse_map_y) - virt_cam_y) * app.tile_size)
		orient := u64(pi.orientation) << 56
		ori := f32(match orient {
			north { 90.0 }
			south { 270.0 }
			west { 180.0 }
			east { 0.0 }
			else { app.log_quit('${@LOCATION} should not get into this else') }
		})

		if pos_x > max_x {
			max_x = pos_x
		}
		if pos_y > max_y {
			max_y = pos_y
		}
		match pi.elem {
			.not {
				app.not_off_coo << pos_x
				app.not_off_coo << pos_y
				app.not_off_coo << ori
			}
			.diode {
				app.diode_off_coo << pos_x
				app.diode_off_coo << pos_y
				app.diode_off_coo << ori
			}
			.on {
				app.on_coo << pos_x
				app.on_coo << pos_y
				app.on_coo << ori
			}
			.wire {
				app.wire_off_coo << pos_x
				app.wire_off_coo << pos_y
			}
			.crossing {
				app.junc_coo << pos_x
				app.junc_coo << pos_y
			}
		}
	}

	mut img_rect := gg.Rect{0, 0, app.tile_size, app.tile_size}

	sgl.enable_texture()
	sgl.texture(app.not_off_img.simg, app.not_off_img.ssmp)
	sgl.c4b(gg.white.r, gg.white.g, gg.white.b, 128)
	for i := 0; i < app.not_off_coo.len; i += 3 {
		app.draw_count += 1
		img_rect.x = app.not_off_coo[i]
		img_rect.y = app.not_off_coo[i + 1]
		draw_image_with_config(img_rect, app.not_off_coo[i + 2])
		if app.draw_count >= app.draw_step {
			app.ensure_draw_count()
			sgl.texture(app.not_off_img.simg, app.not_off_img.ssmp)
		}
	}
	sgl.texture(app.diode_off_img.simg, app.diode_off_img.ssmp)
	for i := 0; i < app.diode_off_coo.len; i += 3 {
		app.draw_count += 1
		img_rect.x = app.diode_off_coo[i]
		img_rect.y = app.diode_off_coo[i + 1]
		draw_image_with_config(img_rect, app.diode_off_coo[i + 2])
		if app.draw_count >= app.draw_step {
			app.ensure_draw_count()
			sgl.texture(app.diode_off_img.simg, app.diode_off_img.ssmp)
		}
	}
	sgl.texture(app.wire_off_img.simg, app.wire_off_img.ssmp)
	for i := 0; i < app.wire_off_coo.len; i += 2 {
		app.draw_count += 1
		img_rect.x = app.wire_off_coo[i]
		img_rect.y = app.wire_off_coo[i + 1]
		draw_image_with_config(img_rect, 0.0)
		if app.draw_count >= app.draw_step {
			app.ensure_draw_count()
			sgl.texture(app.wire_off_img.simg, app.wire_off_img.ssmp)
		}
	}
	sgl.texture(app.junc_img.simg, app.junc_img.ssmp)
	for i := 0; i < app.junc_coo.len; i += 2 {
		app.draw_count += 1
		img_rect.x = app.junc_coo[i]
		img_rect.y = app.junc_coo[i + 1]
		draw_image_with_config(img_rect, 0.0)
		if app.draw_count >= app.draw_step {
			app.ensure_draw_count()
			sgl.texture(app.junc_img.simg, app.junc_img.ssmp)
		}
	}
	sgl.texture(app.on_img.simg, app.on_img.ssmp)
	for i := 0; i < app.on_coo.len; i += 3 {
		app.draw_count += 1
		img_rect.x = app.on_coo[i]
		img_rect.y = app.on_coo[i + 1]
		draw_image_with_config(img_rect, app.on_coo[i + 2])
		if app.draw_count >= app.draw_step {
			app.ensure_draw_count()
			sgl.texture(app.on_img.simg, app.on_img.ssmp)
		}
	}
	sgl.disable_texture()

	app.ctx.draw_rect_filled(m_x, m_y, max_x - m_x + app.tile_size, max_y - m_y + app.tile_size,
		gg.Color{255, 255, 255, 128})
}

fn (mut app App) draw_selection_box() {
	virt_cam_x := app.cam_x - (app.drag_x - app.click_x) / app.tile_size
	virt_cam_y := app.cam_y - (app.drag_y - app.click_y) / app.tile_size
	if app.select_start_x != u32(-1) {
		pos_x := f32((f64(app.select_start_x) - virt_cam_x) * app.tile_size)
		pos_y := f32((f64(app.select_start_y) - virt_cam_y) * app.tile_size)
		app.ctx.draw_square_filled(pos_x, pos_y, app.tile_size, app.palette.selection_start)
	}
	if app.select_end_x != u32(-1) {
		pos_x := f32((f64(app.select_end_x) - virt_cam_x) * app.tile_size)
		pos_y := f32((f64(app.select_end_y) - virt_cam_y) * app.tile_size)
		app.ctx.draw_square_filled(pos_x, pos_y, app.tile_size, app.palette.selection_end)
	}
	if app.select_start_x != u32(-1) && app.select_end_x != u32(-1) {
		x_start, x_end := if app.select_start_x > app.select_end_x {
			app.select_end_x, app.select_start_x
		} else {
			app.select_start_x, app.select_end_x
		}
		y_start, y_end := if app.select_start_y > app.select_end_y {
			app.select_end_y, app.select_start_y
		} else {
			app.select_start_y, app.select_end_y
		}
		pos_x := f32((f64(x_start) - virt_cam_x) * app.tile_size)
		pos_y := f32((f64(y_start) - virt_cam_y) * app.tile_size)
		end_pos_w := f32((f64(x_end + 1) - virt_cam_x) * app.tile_size) - pos_x
		end_pos_h := f32((f64(y_end + 1) - virt_cam_y) * app.tile_size) - pos_y
		app.ctx.draw_rect_filled(pos_x, pos_y, end_pos_w, end_pos_h, app.palette.selection_box)
	}
}

// customized version of gg.draw_image_with_config
fn draw_image_with_config(img_rect gg.Rect, rotation f32) {
	x0 := img_rect.x
	y0 := img_rect.y
	x1 := x0 + img_rect.width
	mut y1 := y0 + img_rect.height

	if rotation != 0 {
		sgl.push_matrix()
		x0_half_width := x0 + (img_rect.width / 2)
		y0_half_height := y0 + (img_rect.height / 2)
		rad := (-rotation * math.pi) / 180.0
		sgl.translate(x0_half_width, y0_half_height, 0)
		sgl.rotate(rad, 0, 0, 1)
		sgl.translate(-x0_half_width, -y0_half_height, 0)
	}

	sgl.begin_quads() // NEEDED to apply the rotation to the quad, move it only if you draw every image with the same rotation
	sgl.v3f_t2f(x0, y0, 0.0, 0, 0)
	sgl.v3f_t2f(x1, y0, 0.0, 1, 0)
	sgl.v3f_t2f(x1, y1, 0.0, 1, 1)
	sgl.v3f_t2f(x0, y1, 0.0, 0, 1)
	sgl.end()

	if rotation != 0 {
		sgl.pop_matrix()
	}
}

@[direct_array_access]
fn (mut app App) draw_map() {
	app.not_on_coo.clear()
	app.not_off_coo.clear()
	app.diode_on_coo.clear()
	app.diode_off_coo.clear()
	app.wire_on_coo.clear()
	app.wire_off_coo.clear()
	app.junc_coo.clear()
	app.on_coo.clear()

	size := app.ctx.window_size()
	// map rendering
	virt_cam_x := app.cam_x - (app.drag_x - app.click_x) / app.tile_size
	virt_cam_y := app.cam_y - (app.drag_y - app.click_y) / app.tile_size
	if app.tile_size > 8 {
		for i in 0 .. (size.width) / app.tile_size + 1 {
			pos_x := f32((int(virt_cam_x) - virt_cam_x + i) * app.tile_size)
			app.ctx.draw_line(pos_x, 0, pos_x, size.height, app.palette.grid)
			app.draw_count += 1
		}
		for i in 0 .. (size.height) / app.tile_size + 1 {
			pos_y := f32((int(virt_cam_y) - virt_cam_y + i) * app.tile_size)
			app.ctx.draw_line(0, pos_y, size.width, pos_y, app.palette.grid)
			app.draw_count += 1
		}
	}

	for chunk in app.map {
		chunk_cam_x := chunk.x - virt_cam_x
		chunk_cam_y := chunk.y - virt_cam_y
		if chunk_cam_x > -chunk_size && chunk_cam_x < size.width && chunk_cam_y > -chunk_size
			&& chunk_cam_y < size.height {
			for off, id in chunk.id_map {
				if id == empty_id {
					continue
				}
				pos_x := f32((chunk_cam_x + off >> chunk_power) * app.tile_size)
				pos_y := f32((chunk_cam_y + off & chunk_bitmask) * app.tile_size)
				if pos_x > size.width {
					break
				}
				if pos_y > size.height {
					continue
				}
				if pos_y > -chunk_size * app.tile_size && pos_x > -chunk_size * app.tile_size {
					if id == elem_crossing_bits { // same bits as wires so need to be separated
						app.junc_coo << pos_x
						app.junc_coo << pos_y
					} else {
						ori := f32(match id & ori_mask {
							north { 90.0 }
							south { 270.0 }
							west { 180.0 }
							east { 0.0 }
							else { app.log_quit('${@LOCATION} should not get into this else') }
						})
						match id & elem_type_mask {
							elem_not_bits {
								if id & on_bits == 0 {
									app.not_on_coo << pos_x
									app.not_on_coo << pos_y
									app.not_on_coo << ori
								} else {
									app.not_off_coo << pos_x
									app.not_off_coo << pos_y
									app.not_off_coo << ori
								}
							}
							elem_diode_bits {
								if id & on_bits == 0 {
									app.diode_off_coo << pos_x
									app.diode_off_coo << pos_y
									app.diode_off_coo << ori
								} else {
									app.diode_on_coo << pos_x
									app.diode_on_coo << pos_y
									app.diode_on_coo << ori
								}
							}
							elem_on_bits {
								app.on_coo << pos_x
								app.on_coo << pos_y
								app.on_coo << ori
							}
							elem_wire_bits {
								if id & on_bits == 0 {
									app.wire_off_coo << pos_x
									app.wire_off_coo << pos_y
								} else {
									app.wire_on_coo << pos_x
									app.wire_on_coo << pos_y
								}
							}
							else {
								app.log_quit('${@LOCATION} should not get into this else')
							}
						}
					}
				}
			}
		}
	}

	mut img_rect := gg.Rect{0, 0, app.tile_size, app.tile_size}

	sgl.c4b(gg.white.r, gg.white.g, gg.white.b, gg.white.a)
	sgl.enable_texture()
	sgl.texture(app.not_on_img.simg, app.not_on_img.ssmp)
	for i := 0; i < app.not_on_coo.len; i += 3 {
		app.draw_count += 1
		img_rect.x = app.not_on_coo[i]
		img_rect.y = app.not_on_coo[i + 1]
		draw_image_with_config(img_rect, app.not_on_coo[i + 2])
		if app.draw_count >= app.draw_step {
			app.ensure_draw_count()
			sgl.texture(app.not_on_img.simg, app.not_on_img.ssmp)
		}
	}
	sgl.texture(app.not_off_img.simg, app.not_off_img.ssmp)
	for i := 0; i < app.not_off_coo.len; i += 3 {
		app.draw_count += 1
		img_rect.x = app.not_off_coo[i]
		img_rect.y = app.not_off_coo[i + 1]
		draw_image_with_config(img_rect, app.not_off_coo[i + 2])
		if app.draw_count >= app.draw_step {
			app.ensure_draw_count()
			sgl.texture(app.not_off_img.simg, app.not_off_img.ssmp)
		}
	}
	sgl.texture(app.diode_on_img.simg, app.diode_on_img.ssmp)
	for i := 0; i < app.diode_on_coo.len; i += 3 {
		app.draw_count += 1
		img_rect.x = app.diode_on_coo[i]
		img_rect.y = app.diode_on_coo[i + 1]
		draw_image_with_config(img_rect, app.diode_on_coo[i + 2])
		if app.draw_count >= app.draw_step {
			app.ensure_draw_count()
			sgl.texture(app.diode_on_img.simg, app.diode_on_img.ssmp)
		}
	}
	sgl.texture(app.diode_off_img.simg, app.diode_off_img.ssmp)
	for i := 0; i < app.diode_off_coo.len; i += 3 {
		app.draw_count += 1
		img_rect.x = app.diode_off_coo[i]
		img_rect.y = app.diode_off_coo[i + 1]
		draw_image_with_config(img_rect, app.diode_off_coo[i + 2])
		if app.draw_count >= app.draw_step {
			app.ensure_draw_count()
			sgl.texture(app.diode_off_img.simg, app.diode_off_img.ssmp)
		}
	}
	sgl.texture(app.wire_on_img.simg, app.wire_on_img.ssmp)
	for i := 0; i < app.wire_on_coo.len; i += 2 {
		app.draw_count += 1
		img_rect.x = app.wire_on_coo[i]
		img_rect.y = app.wire_on_coo[i + 1]
		draw_image_with_config(img_rect, 0.0)
		if app.draw_count >= app.draw_step {
			app.ensure_draw_count()
			sgl.texture(app.wire_on_img.simg, app.wire_on_img.ssmp)
		}
	}
	sgl.texture(app.wire_off_img.simg, app.wire_off_img.ssmp)
	for i := 0; i < app.wire_off_coo.len; i += 2 {
		app.draw_count += 1
		img_rect.x = app.wire_off_coo[i]
		img_rect.y = app.wire_off_coo[i + 1]
		draw_image_with_config(img_rect, 0.0)
		if app.draw_count >= app.draw_step {
			app.ensure_draw_count()
			sgl.texture(app.wire_off_img.simg, app.wire_off_img.ssmp)
		}
	}
	sgl.texture(app.junc_img.simg, app.junc_img.ssmp)
	for i := 0; i < app.junc_coo.len; i += 2 {
		app.draw_count += 1
		img_rect.x = app.junc_coo[i]
		img_rect.y = app.junc_coo[i + 1]
		draw_image_with_config(img_rect, 0.0)
		if app.draw_count >= app.draw_step {
			app.ensure_draw_count()
			sgl.texture(app.junc_img.simg, app.junc_img.ssmp)
		}
	}
	sgl.texture(app.on_img.simg, app.on_img.ssmp)
	for i := 0; i < app.on_coo.len; i += 3 {
		app.draw_count += 1
		img_rect.x = app.on_coo[i]
		img_rect.y = app.on_coo[i + 1]
		draw_image_with_config(img_rect, app.on_coo[i + 2])
		if app.draw_count >= app.draw_step {
			app.ensure_draw_count()
			sgl.texture(app.on_img.simg, app.on_img.ssmp)
		}
	}
	sgl.disable_texture()
}

fn (mut app App) ensure_draw_count() {
	sgl.disable_texture()
	app.ctx.end(how: .passthru)
	app.ctx.begin()
	app.draw_count = 1
	sgl.enable_texture()
}

fn (app App) check_ui_button_click_y(but Buttons, mouse_y f32) bool {
	pos := unsafe { app.buttons[but].pos }
	return mouse_y >= (pos * (button_top_padding + button_size + button_top_padding)) * app.ui
		&& mouse_y < ((pos + 1) * (button_top_padding + button_size) + button_top_padding) * app.ui
}

fn (app App) ingame_ui_button_click_to_nb(mouse_x f32, mouse_y f32) int {
	if !(mouse_x >= app.ui * button_left_padding
		&& mouse_x < app.ui * (button_size + button_left_padding)) { // button area
		return -1
	}
	return int((mouse_y - app.ui * button_top_padding) / (app.ui * (button_top_padding + button_size)))
}

fn (mut app App) handle_ingame_ui_button_interrac(b Buttons) {
	if b == .cancel_button {
		app.disable_all_ingame_modes()
		app.tmp_pos_x = u32(-1)
		app.tmp_pos_y = u32(-1)
		app.place_start_x = u32(-1)
		app.text_input = ''
	} else if b == .edit_color {
		if app.selected_colorchip == -1 {
			app.log('No ColorChip selected', .warn)
		} else {
			app.disable_all_ingame_modes()
			app.colorchips_hidden = false
			app.edit_mode = true
			app.edit_color_submode = true
		}
	} else if b == .choose_colorchip {
		app.disable_all_ingame_modes()
		app.edit_mode = true
		app.choose_colorchip_submode = true
	} else if b == .add_input {
		if app.selected_colorchip == -1 {
			app.log('No ColorChip selected', .warn)
		} else {
			app.disable_all_ingame_modes()
			app.edit_mode = true
			app.add_input_submode = true
		}
	} else if b == .copy_settings {
		if app.selected_colorchip == -1 {
			app.log('No ColorChip selected', .warn)
		} else {
			app.disable_all_ingame_modes()
			app.colorchips_hidden = false
			app.edit_mode = true
			app.copy_settings_submode = true
		}
	} else if b == .delete_colorchip {
		app.disable_all_ingame_modes()
		app.colorchips_hidden = false
		app.edit_mode = true
		app.delete_colorchip_submode = true
	} else if b == .item_nots {
		if !app.placement_mode {
			app.disable_all_ingame_modes()
			app.placement_mode = true
		}
		app.selected_item = .not
	} else if b == .item_diode {
		if !app.placement_mode {
			app.disable_all_ingame_modes()
			app.placement_mode = true
		}
		app.selected_item = .diode
	} else if b == .item_crossing {
		if !app.placement_mode {
			app.disable_all_ingame_modes()
			app.placement_mode = true
		}
		app.selected_item = .crossing
	} else if b == .item_on {
		if !app.placement_mode {
			app.disable_all_ingame_modes()
			app.placement_mode = true
		}
		app.selected_item = .on
	} else if b == .item_wire {
		if !app.placement_mode {
			app.disable_all_ingame_modes()
			app.placement_mode = true
		}
		app.selected_item = .wire
	} else if b == .rotate_copy {
		if app.e.modifiers & 1 == 1 || app.e.mouse_button == .right { // shift: 1<<0
			app.todo << TodoInfo{.rotate, 0, 0, 0, 0, 'l'}
		} else {
			app.todo << TodoInfo{.rotate, 0, 0, 0, 0, 'r'}
		}
	} else if b == .load_gate {
		app.disable_all_ingame_modes()
		app.load_gate_mode = true
	} else if b == .flip_h {
		app.todo << TodoInfo{.flip_h, 0, 0, 0, 0, ''}
	} else if b == .flip_v {
		app.todo << TodoInfo{.flip_v, 0, 0, 0, 0, ''}
	} else if b == .confirm_save_gate {
		if app.text_input != '' && app.select_start_x != u32(-1) && app.select_end_x != u32(-1) {
			if !os.exists('saved_gates/${app.text_input}') {
				app.disable_all_ingame_modes()
				// copies because save_gate saves the copied gate
				app.todo << TodoInfo{.copy, app.select_start_x, app.select_start_y, app.select_end_x, app.select_end_y, ''}
				app.todo << TodoInfo{.save_gate, 0, 0, 0, 0, app.text_input}
				app.text_input = ''
				app.select_start_x = u32(-1)
				app.select_end_x = u32(-1)
			} else {
				app.log('Gate ${app.text_input} already exists', .warn)
			}
		}
	} else if b == .copy_button {
		if app.select_start_x != u32(-1) && app.select_start_y != u32(-1)
			&& app.select_end_x != u32(-1) && app.select_end_y != u32(-1) {
			app.todo << TodoInfo{.copy, app.select_start_x, app.select_start_y, app.select_end_x, app.select_end_y, ''}
			app.log('Copied selection', .info)
		} else {
			app.log('Please select an area first (with [left&right] clicks)', .warn)
		}
	} else if b == .selection_delete {
		app.todo << TodoInfo{.removal, app.select_start_x, app.select_start_y, app.select_end_x, app.select_end_y, ''}
	} else if b == .paste {
		app.disable_all_ingame_modes()
		app.paste_mode = true
	} else if b == .save_gate {
		if app.select_start_x != u32(-1) && app.select_start_y != u32(-1)
			&& app.select_end_x != u32(-1) && app.select_end_y != u32(-1) {
			app.disable_all_ingame_modes()
			app.save_gate_mode = true
			app.text_input = ''
		} else {
			app.log('Please select an area first (with [left&right] clicks)', .warn)
		}
	} else if b == .create_color_chip {
		if app.select_start_x != u32(-1) && app.select_start_y != u32(-1)
			&& app.select_end_x != u32(-1) && app.select_end_y != u32(-1) {
			app.disable_all_ingame_modes()
			app.edit_mode = true
			app.edit_color_submode = true
			app.selected_colorchip = app.colorchips.len
			x_start, x_end := if app.select_start_x > app.select_end_x {
				app.select_end_x, app.select_start_x
			} else {
				app.select_start_x, app.select_end_x
			}
			y_start, y_end := if app.select_start_y > app.select_end_y {
				app.select_end_y, app.select_start_y
			} else {
				app.select_start_y, app.select_end_y
			}
			app.colorchips << ColorChip{x_start, y_start, x_end - x_start + 1, y_end - y_start + 1, [
				default_colorchip_color_off,
				default_colorchip_color_on,
			], [Coo{x_start, y_start}]}
			app.select_start_x = u32(-1)
			app.select_start_y = u32(-1)
			app.select_end_x = u32(-1)
			app.select_end_y = u32(-1)
		} else {
			app.log('Please select an area first (with [left&right] clicks)', .warn)
		}
	} else if b == .selection_button {
		app.disable_all_ingame_modes()
		app.selection_mode = true
	} else if b == .speed {
		app.nb_updates += 1
	} else if b == .slow {
		if app.nb_updates > 1 {
			app.nb_updates -= 1
		}
	} else if b == .pause {
		app.pause = !app.pause
	} else if b == .save_map {
		app.todo << TodoInfo{.save_map, 0, 0, 0, 0, app.map_name}
		// WIP
	} else if b == .quit_map {
		app.quit_map()
	} else if b == .cc_mode {
		app.disable_all_ingame_modes()
		app.edit_mode = true
		app.choose_colorchip_submode = true
	} else if b == .hide_colorchips {
		app.colorchips_hidden = !app.colorchips_hidden
	} else if b == .keyinput {
		app.disable_all_ingame_modes()
		app.keyinput_mode = true
	}
}

// 0 for the first button
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
		} else { // no mode
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
	return mouse_y >= app.ui * (pos * (maps_top_spacing + maps_y_offset) + maps_y_offset)
		&& mouse_y < app.ui * ((pos + 1) * (maps_top_spacing + maps_y_offset) + maps_y_offset)
}

fn (app App) check_gates_button_click_y(pos int, mouse_y f32) bool {
	return mouse_y >= app.ui * (pos * (gate_top_spacing + gate_h) + gate_y_offset)
		&& mouse_y < app.ui * ((pos + 1) * (gate_top_spacing + gate_h) + gate_y_offset)
}

fn (mut app App) disable_all_ingame_modes() {
	app.editmenu_selected_color = 0
	app.edit_mode = false
	app.copy_settings_submode = false
	app.choose_colorchip_submode = false
	app.create_colorchip_submode = false
	app.edit_color_submode = false
	app.add_input_submode = false
	app.delete_colorchip_submode = false
	app.placement_mode = false
	app.selection_mode = false
	app.load_gate_mode = false
	app.paste_mode = false
	app.keyinput_mode = false
	app.save_gate_mode = false
	app.scroll_pos = 0.0
	app.move_down = false
}

fn (mut app App) go_map_menu() {
	app.main_menu = false
	app.solo_menu = true
	app.map_delete_nb = -1
	app.text_input = ''
	if !os.exists(maps_path) {
		if !os.exists(player_data_path) {
			os.mkdir(player_data_path) or {
				app.log('Cannot create ${player_data_path}, ${err}', .err)
				return
			}
		}
		os.mkdir(maps_path) or {
			app.log('Cannot create ${maps_path}, ${err}', .err)
			return
		}
	}
	if !os.exists(gates_path) {
		if !os.exists(player_data_path) {
			os.mkdir(player_data_path) or {
				app.log('Cannot create ${player_data_path}, ${err}', .err)
				return
			}
		}
		os.mkdir(gates_path) or {
			app.log('Cannot create ${maps_path}, ${err}', .err)
			return
		}
	}
	app.map_names_list = os.ls(maps_path) or {
		app.log('Cannot list files in ${maps_path}, ${err}', .err)
		return
	}
}

fn (mut app App) load_saved_game(name string) {
	/// server side
	app.load_map(name) or {
		app.log('Cannot load map ${name}, ${err}', .err)
		return
	}
	app.map_name = name
	app.pause = false
	app.todo = []
	app.selected_item = .not
	app.selected_ori = north
	app.copied = []
	app.comp_running = true
	///
	app.solo_menu = false
	app.text_input = ''
	app.cl_thread = spawn app.computation_loop()
	app.cam_x = default_camera_pos_x
	app.cam_y = default_camera_pos_y
}

fn (mut app App) clear_server_state() {
	app.map = []Chunk{}
	app.text_input = ''
	app.pause = false
	app.nb_updates = 5
	app.todo = []
	app.selected_item = .not
	app.selected_ori = north
	app.copied = []
	app.actual_state = 0
	app.nots = nots_array_default.clone() // to start the rid at 1
	app.n_states = [[false], [false]]! // the old state and the actual state list
	app.dead_nots = []
	app.dead_nots_lower = 0
	app.diodes = diode_array_default.clone()
	app.d_states = [[false], [false]]!
	app.dead_diodes = []
	app.dead_diodes_lower = 0
	app.wires = wire_array_default.clone()
	app.w_states = [[false], [false]]!
	app.dead_wires = []
	app.dead_wires_lower = 0
	app.forced_states = []
	app.key_pos = {}
	app.colorchips = []
	app.chunk_cache = {}
}

fn (mut app App) create_game() {
	if !os.exists(maps_path + app.text_input) {
		app.disable_all_ingame_modes()
		app.solo_menu = false
		/// serverside
		app.map_name = app.text_input
		app.clear_server_state()
		app.comp_running = true
		///
		app.cl_thread = spawn app.computation_loop()
		app.cam_x = default_camera_pos_x
		app.cam_y = default_camera_pos_y
	} else {
		app.log('Map ${app.text_input} already exists', .warn)
	}
}

fn (mut app App) back_to_main_menu() {
	app.disable_all_ingame_modes()
	app.solo_menu = false
	app.main_menu = true
}

fn (mut app App) check_and_delete_colorchip_input(mouse_x f32, mouse_y f32) {
	for i in 0 .. app.colorchips[app.selected_colorchip].inputs.len {
		x := app.ui * (editmenu_offset_inputs_x + editmenu_offset_x) +
			i % app.editmenu_nb_inputs_by_row * app.ui * (editmenu_inputsize +
			editmenu_input_x_space)
		y := app.ui * (editmenu_offset_inputs_y + editmenu_offset_y) +
			i / app.editmenu_nb_inputs_by_row * app.ui * editmenu_inputsize
		if mouse_x >= x && mouse_x < x + app.ui * editmenu_inputsize {
			if mouse_y >= y && mouse_y < y + app.ui * editmenu_inputsize {
				if app.e.mouse_button == .right {
					/*
					app.colorchips[app.selected_colorchip].inputs.delete(i)
					for app.colorchips[app.selected_colorchip].colors.len > pow(2, app.colorchips[app.selected_colorchip].inputs.len) {
						app.colorchips[app.selected_colorchip].colors.delete(app.colorchips[app.selected_colorchip].colors.len - 1)
					}
					*/
				} else if app.e.mouse_button == .left {
					app.cam_x = app.colorchips[app.selected_colorchip].inputs[i].x - u32(app.s.width / 2 / app.tile_size)
					app.cam_y = app.colorchips[app.selected_colorchip].inputs[i].y - u32(app.s.height / 2 / app.tile_size)
				}
			}
		}
	}
}

fn (mut app App) check_and_select_color_cc(mouse_x f32, mouse_y f32) {
	last_rel_input_y := (app.colorchips[app.selected_colorchip].inputs.len - 1) / app.editmenu_nb_inputs_by_row * app.ui * editmenu_inputsize
	for i in 0 .. app.colorchips[app.selected_colorchip].colors.len {
		x := app.ui * (editmenu_offset_x + editmenu_offset_colors_x) +
			i % app.editmenu_nb_color_by_row * app.ui * editmenu_colorsize
		y := app.ui * (editmenu_offset_y + editmenu_offset_colors_y) +
			i / app.editmenu_nb_color_by_row * app.ui * editmenu_colorsize + last_rel_input_y
		if mouse_x >= x && mouse_x < x + app.ui * editmenu_colorsize {
			if mouse_y >= y && mouse_y < y + app.ui * editmenu_colorsize {
				if app.e.mouse_button == .left {
					app.editmenu_selected_color = i
				}
			}
		}
	}
}

fn (mut app App) check_and_change_color_cc(mouse_x f32, mouse_y f32) {
	if mouse_y >= app.ui * (editmenu_rgb_y + editmenu_offset_y)
		&& mouse_y < app.ui * (editmenu_rgb_y + editmenu_offset_y + editmenu_rgb_h) {
		if mouse_x >= app.ui * (editmenu_r_x + editmenu_offset_x)
			&& mouse_x < app.ui * (editmenu_r_x + editmenu_offset_x + editmenu_rgb_w) {
			if app.e.mouse_button == .left {
				app.colorchips[app.selected_colorchip].colors[app.editmenu_selected_color].r += 1
			} else if app.e.mouse_button == .right {
				app.colorchips[app.selected_colorchip].colors[app.editmenu_selected_color].r -= 1
			}
		}
		if mouse_x >= app.ui * (editmenu_g_x + editmenu_offset_x)
			&& mouse_x < app.ui * (editmenu_g_x + editmenu_offset_x + editmenu_rgb_w) {
			if app.e.mouse_button == .left {
				app.colorchips[app.selected_colorchip].colors[app.editmenu_selected_color].g += 1
			} else if app.e.mouse_button == .right {
				app.colorchips[app.selected_colorchip].colors[app.editmenu_selected_color].g -= 1
			}
		}
		if mouse_x >= app.ui * (editmenu_b_x + editmenu_offset_x)
			&& mouse_x < app.ui * (editmenu_b_x + editmenu_offset_x + editmenu_rgb_w) {
			if app.e.mouse_button == .left {
				app.colorchips[app.selected_colorchip].colors[app.editmenu_selected_color].b += 1
			} else if app.e.mouse_button == .right {
				app.colorchips[app.selected_colorchip].colors[app.editmenu_selected_color].b -= 1
			}
		}
	}
}

fn (mut app App) delete_colorchip_at(mouse_x f32, mouse_y f32) {
	map_x := u32(app.cam_x + (mouse_x / app.tile_size))
	map_y := u32(app.cam_y + (mouse_y / app.tile_size))
	mut del_i := -1
	for i, cc in app.colorchips {
		if map_x >= cc.x && map_x < cc.x + cc.w && map_y >= cc.y && map_y < cc.y + cc.h {
			del_i = i
			break
		}
	}
	if del_i > -1 {
		app.colorchips.delete(del_i)
		if app.selected_colorchip == del_i {
			app.selected_colorchip = -1
		}
	}
}

fn (mut app App) load_gate_and_paste_mode(name string) {
	app.disable_all_ingame_modes()
	app.paste_mode = true
	app.text_input = ''
	app.todo << TodoInfo{.load_gate, 0, 0, 0, 0, name}
}

fn (mut app App) placement_released_at(mouse_x f32, mouse_y f32, e &gg.Event) {
	app.place_down = false
	app.place_end_x = u32(app.cam_x + mouse_x / app.tile_size)
	app.place_end_y = u32(app.cam_y + mouse_y / app.tile_size)
	x_diff := app.place_start_x - app.place_end_x
	y_diff := app.place_start_y - app.place_end_y
	if x_diff * x_diff >= y_diff * y_diff {
		app.place_end_y = app.place_start_y
		if app.place_start_x > app.place_end_x {
			app.selected_ori = west
		} else {
			app.selected_ori = east
		}
		if e.mouse_button == .left {
			// start_y at the end because it's a X placement
			app.todo << TodoInfo{.place, app.place_start_x, app.place_start_y, app.place_end_x, app.place_start_y, ''}
		} else if e.mouse_button == .right {
			app.todo << TodoInfo{.removal, app.place_start_x, app.place_start_y, app.place_end_x, app.place_start_y, ''}
		}
	} else {
		app.place_end_x = app.place_start_x
		if app.place_start_y > app.place_end_y {
			app.selected_ori = north
		} else {
			app.selected_ori = south
		}
		if e.mouse_button == .left {
			// start_x at the end because it's a Y placement
			app.todo << TodoInfo{.place, app.place_start_x, app.place_start_y, app.place_start_x, app.place_end_y, ''}
		} else if e.mouse_button == .right {
			app.todo << TodoInfo{.removal, app.place_start_x, app.place_start_y, app.place_start_x, app.place_end_y, ''}
		}
	}
	app.place_start_x = u32(-1)
	app.place_start_y = u32(-1)
	app.place_end_x = u32(-1)
	app.place_end_y = u32(-1)
}

fn (mut app App) quit_map() {
	app.disable_all_ingame_modes()
	app.todo << TodoInfo{.quit, 0, 0, 0, 0, app.map_name}
	app.cl_thread.wait()
	app.main_menu = true
}

fn (mut app App) handle_ingame_ui_button_click(mouse_x f32, mouse_y f32) {
	nb := app.ingame_ui_button_click_to_nb(mouse_x, mouse_y)
	btn := app.convert_button_nb_to_enum(nb) or { return }
	app.handle_ingame_ui_button_interrac(btn)
}

fn (mut app App) handle_ingame_ui_button_keybind(nb int) {
	btn := app.convert_button_nb_to_enum(nb) or { return }
	app.handle_ingame_ui_button_interrac(btn)
}

fn (mut app App) scroll() {
	if app.comp_running {
		if app.e.scroll_y > 0 {
			app.tile_size += 1
		} else {
			app.tile_size -= 1
		}
		if app.tile_size < 1 {
			app.tile_size = 1
		}
	}
}

fn (mut app App) update_mouse_action() {
	if app.comp_running {
		if app.e.mouse_x < app.ui * ui_width {
			nb := app.ingame_ui_button_click_to_nb(app.e.mouse_x, app.e.mouse_y)
			btn := app.convert_button_nb_to_enum(nb) or { return }
			match btn {
				.rotate_copy {
					app.mouse_action = '[left] rotate cw [right/left+shift] rotate ccw'
				}
				.cc_mode {
					app.mouse_action = 'colorchips edit mode'
				}
				else {
					app.mouse_action = btn.str()
				}
			}
		} else {
			if app.keyinput_mode {
				app.mouse_action = '[left] set pos (keyboard input afterwards) [right] delete key input [middle] camera'
			} else if app.selection_mode {
				app.mouse_action = '[left] start of selection [right] end of selection [middle] camera'
			} else if app.save_gate_mode {
				app.mouse_action = '[middle] camera'
			} else if app.paste_mode {
				app.mouse_action = '[left] paste [middle] camera'
			} else if app.placement_mode {
				app.mouse_action = '[drag left] place [drag right] remove [middle] camera'
			} else if app.load_gate_mode {
				app.mouse_action = '[middle] camera'
			} else if app.edit_mode {
				if app.choose_colorchip_submode {
					app.mouse_action = '[left] select colorchip [middle] camera'
				} else if app.edit_color_submode {
					app.mouse_action = '[left/right] adjust colorchip settings [middle] camera'
				} else if app.add_input_submode {
					app.mouse_action = '[left] new input [right] delete input [middle] camera'
				} else if app.copy_settings_submode {
					app.mouse_action = '[left] copy selected settings to clicked colorchip [middle] camera'
				} else if app.delete_colorchip_submode {
					app.mouse_action = '[left/right] delete colorchip [middle] camera'
				}
			} else {
				app.mouse_action = '[left/right/middle] camera'
			}
		}
	} else {
		app.mouse_action = ''
	}
}

fn on_event(e &gg.Event, mut app App) {
	app.s = app.ctx.window_size()
	app.ui = f32(app.s.height) / f32(default_win_height)
	unsafe {
		app.e = e
	}
	mouse_x := if e.mouse_x < 1.0 {
		1.0
	} else {
		e.mouse_x
	}
	mouse_y := if e.mouse_y < 1.0 {
		1.0
	} else {
		e.mouse_y
	}
	app.scroll_pos += e.scroll_y
	if app.scroll_pos < 0 {
		app.scroll_pos = 0
	}
	app.mouse_map_x = u32(app.cam_x + mouse_x / app.tile_size)
	app.mouse_map_y = u32(app.cam_y + mouse_y / app.tile_size)
	app.update_mouse_action()
	match e.typ {
		.mouse_up {
			if app.debug_mode && e.modifiers & 1 == 1 { // shift
				app.update_cycle()
			}
			app.mouse_down = false
			if app.main_menu {
				if mouse_x >= app.ui * button_solo_x
					&& mouse_x < app.ui * (button_solo_x + button_solo_w)
					&& mouse_y >= app.ui * button_solo_y
					&& mouse_y < app.ui * (button_solo_y + button_solo_h) {
					app.go_map_menu()
				} else if mouse_x >= app.ui * btn_quit_ofst
					&& mouse_x < app.ui * (btn_quit_ofst + button_quit_size)
					&& mouse_y >= app.ui * btn_quit_y
					&& mouse_y < app.ui * (btn_quit_y + button_quit_size) {
					exit(0)
				}
			} else if app.solo_menu {
				if mouse_x >= app.ui * maps_x_offset {
					app.map_names_list = os.ls(maps_path) or {
						app.log('Cannot list files in ${maps_path}, ${err}', .err)
						return
					}
					for i, name in app.map_names_list.filter(it.contains(app.text_input)) { // the maps are filtered with the search field
						if e.mouse_button == .left {
							if app.check_maps_button_click_y(i, mouse_y) {
								map_end_x := app.ui * (maps_x_offset + maps_w)
								if mouse_x < map_end_x {
									app.load_saved_game(name)
									return
								} else if mouse_x < map_end_x + app.ui * maps_h {
									app.map_delete_nb = i
									return
								} else if app.map_delete_nb == i
									&& mouse_x < map_end_x + 2 * app.ui * maps_h {
									app.map_delete_nb = -1
									os.rm(maps_path + name) or {
										app.log('${@LOCATION}: ${err}', .warn)
									}
									app.map_names_list = os.ls(maps_path) or {
										app.log('Cannot list files in ${maps_path}, ${err}',
											.err)
										return
									}
									return
								}
							}
						}
					}
				}
				if mouse_x >= app.ui * button_new_map_x
					&& mouse_x < app.ui * (button_new_map_x + button_new_map_size)
					&& mouse_y >= app.ui * button_new_map_y
					&& mouse_y < app.ui * (button_new_map_y + button_new_map_size) {
					if app.text_input != '' {
						app.create_game()
					} else {
						app.log('Please input a name for the new map', .info)
					}
				} else if mouse_x >= app.ui * btn_back_x
					&& mouse_x < app.ui * (btn_back_x + btn_back_s)
					&& mouse_y >= app.ui * btn_back_y
					&& mouse_y < app.ui * (btn_back_y + btn_back_s) {
					app.back_to_main_menu()
				}
			} else if app.comp_running {
				if app.keyinput_mode {
					if app.move_down {
						if e.mouse_button == .middle {
							app.finish_move_cam()
						}
					} else if mouse_x < app.ui * ui_width {
						app.handle_ingame_ui_button_click(mouse_x, mouse_y)
					} else {
						map_x := app.cam_x + (mouse_x / app.tile_size)
						map_y := app.cam_y + (mouse_y / app.tile_size)
						// right click -> delete the pos = click_pos encountered in the map
						// left click -> waiting for input, when input, save pos & key in the map
						if e.mouse_button == .right {
							app.tmp_pos_x = u32(-1)
							app.tmp_pos_y = u32(-1)
							for key in app.key_pos.keys() {
								i := app.key_pos[key].index(Coo{u32(map_x), u32(map_y)})
								if i != -1 {
									app.key_pos[key].delete(i) // it will delete all the "buttons" on this tile, but the multiple buttons are not intended anyways	
								}
							}
						} else if e.mouse_button == .left {
							app.tmp_pos_x = u32(map_x)
							app.tmp_pos_y = u32(map_y)
						}
					}
				} else if app.edit_mode {
					if app.move_down {
						if e.mouse_button == .middle {
							app.finish_move_cam()
						}
					} else if mouse_x < app.ui * ui_width {
						app.handle_ingame_ui_button_click(mouse_x, mouse_y)
					} else {
						if app.edit_color_submode && app.selected_colorchip != -1 {
							app.check_and_delete_colorchip_input(mouse_x, mouse_y)
							app.check_and_select_color_cc(mouse_x, mouse_y)
						} else if app.delete_colorchip_submode {
							app.delete_colorchip_at(mouse_x, mouse_y)
						} else if app.add_input_submode && app.selected_colorchip != -1 {
							if e.mouse_button == .left {
								if app.colorchips[app.selected_colorchip].inputs.len < 9 {
									app.colorchips[app.selected_colorchip].inputs << Coo{u32(
										app.cam_x + (mouse_x / app.tile_size)), u32(app.cam_y +
										(mouse_y / app.tile_size))}
									for app.colorchips[app.selected_colorchip].colors.len < pow(2,
										app.colorchips[app.selected_colorchip].inputs.len) {
										app.colorchips[app.selected_colorchip].colors << gg.white
									}
								} else {
									app.log('Cannot add more inputs to the colorchip',
										.info)
								}
							} else if e.mouse_button == .right {
								coo := Coo{u32(app.cam_x + (mouse_x / app.tile_size)), u32(
									app.cam_y + (mouse_y / app.tile_size))}
								i := app.colorchips[app.selected_colorchip].inputs.index(coo)
								if i >= 0 {
									app.colorchips[app.selected_colorchip].inputs.delete(i)
									for app.colorchips[app.selected_colorchip].colors.len > pow(2,
										app.colorchips[app.selected_colorchip].inputs.len) {
										app.colorchips[app.selected_colorchip].colors.delete(app.colorchips[app.selected_colorchip].colors.len - 1)
									}
								}
							}
						} else if app.choose_colorchip_submode {
							map_x := u32(app.cam_x + (mouse_x / app.tile_size))
							map_y := u32(app.cam_y + (mouse_y / app.tile_size))
							for i, cc in app.colorchips {
								if map_x >= cc.x && map_x < cc.x + cc.w && map_y >= cc.y
									&& map_y < cc.y + cc.h {
									app.selected_colorchip = i
									break
								}
							}
						} else if app.copy_settings_submode && app.selected_colorchip != -1 {
							map_x := u32(app.cam_x + (mouse_x / app.tile_size))
							map_y := u32(app.cam_y + (mouse_y / app.tile_size))
							for i, cc in app.colorchips {
								if map_x >= cc.x && map_x < cc.x + cc.w && map_y >= cc.y
									&& map_y < cc.y + cc.h {
									app.colorchips[i].inputs = []Coo{cap: app.colorchips[app.selected_colorchip].inputs.len}
									cur_x := app.colorchips[i].x
									cur_y := app.colorchips[i].y
									sel_x := app.colorchips[app.selected_colorchip].x
									sel_y := app.colorchips[app.selected_colorchip].y
									for inp in app.colorchips[app.selected_colorchip].inputs {
										app.colorchips[i].inputs << Coo{inp.x - sel_x + cur_x,
											inp.y - sel_y + cur_y}
									}
									app.colorchips[i].colors = app.colorchips[app.selected_colorchip].colors.clone()
									app.log('Settings copied', .info)
									break
								}
							}
						}
					}
				} else if app.load_gate_mode {
					if app.move_down {
						if e.mouse_button == .middle {
							app.finish_move_cam()
						}
					} else if mouse_x < app.ui * ui_width {
						app.handle_ingame_ui_button_click(mouse_x, mouse_y)
					} else {
						if !os.exists(gates_path) {
							if !os.exists(player_data_path) {
								os.mkdir(player_data_path) or {
									app.log('Cannot create ${player_data_path}, ${err}',
										.err)
									return
								}
							}
							os.mkdir(gates_path) or {
								app.log('Cannot create ${gates_path}, ${err}', .err)
								return
							}
						}
						app.gate_name_list = os.ls(gates_path) or {
							app.log('cannot list files in ${gates_path}, ${err}', .err)
							return
						}
						if mouse_x >= app.ui * (ui_width + gate_x_ofst)
							&& mouse_x < app.ui * (ui_width + gate_x_ofst + gate_w) {
							for i, name in app.gate_name_list.filter(it.contains(app.text_input)) { // the maps are filtered with the search field
								if e.mouse_button == .left {
									if app.check_gates_button_click_y(i, mouse_y) {
										app.load_gate_and_paste_mode(name)
									}
								}
							}
						}
					}
				} else if app.placement_mode {
					if app.place_down && e.mouse_button != .middle { // TODO: make the UI disappear/fade out when doing a placement
						app.placement_released_at(mouse_x, mouse_y, e)
					} else if app.move_down {
						if e.mouse_button == .middle {
							app.finish_move_cam()
						}
					} else if mouse_x < app.ui * ui_width {
						app.handle_ingame_ui_button_click(mouse_x, mouse_y)
					}
				} else if app.paste_mode {
					if app.move_down {
						if e.mouse_button == .middle {
							app.finish_move_cam()
						}
					} else if mouse_x < app.ui * ui_width {
						app.handle_ingame_ui_button_click(mouse_x, mouse_y)
					} else {
						if e.mouse_button == .left {
							app.todo << TodoInfo{.paste, u32(app.cam_x + mouse_x / app.tile_size), u32(
								app.cam_y + mouse_y / app.tile_size), 0, 0, ''}
						}
					}
				} else if app.save_gate_mode {
					if app.move_down {
						if e.mouse_button == .middle {
							app.finish_move_cam()
						}
					} else if mouse_x < app.ui * ui_width {
						app.handle_ingame_ui_button_click(mouse_x, mouse_y)
					}
				} else if app.selection_mode {
					if app.move_down {
						if e.mouse_button == .middle {
							app.finish_move_cam()
						}
					} else if mouse_x < app.ui * ui_width {
						app.handle_ingame_ui_button_click(mouse_x, mouse_y)
					} else {
						if e.mouse_button == .left {
							app.select_start_x = u32(app.cam_x + mouse_x / app.tile_size)
							app.select_start_y = u32(app.cam_y + mouse_y / app.tile_size)
						} else if e.mouse_button == .right {
							app.select_end_x = u32(app.cam_x + mouse_x / app.tile_size)
							app.select_end_y = u32(app.cam_y + mouse_y / app.tile_size)
						}
					}
				} else {
					if app.move_down {
						app.finish_move_cam()
					} else if mouse_x < app.ui * ui_width {
						app.handle_ingame_ui_button_click(mouse_x, mouse_y)
					}
				}
			}
		}
		.mouse_down {
			app.mouse_down = true
			app.editmenu_hold = 0
		}
		.mouse_scroll {
			app.scroll()
		}
		.key_up {
			if !(app.solo_menu || app.load_gate_mode || app.keyinput_mode || app.save_gate_mode) {
				match e.key_code {
					._0, ._1, ._2, ._3, ._4, ._5, ._6, ._7, ._8, ._9 {
						app.handle_ingame_ui_button_keybind(int(e.key_code) - 48)
					}
					.p {
						app.handle_ingame_ui_button_interrac(.paste)
					}
					.enter {
						app.handle_ingame_ui_button_interrac(.save_map)
					}
					.space {
						app.handle_ingame_ui_button_interrac(.pause)
					}
					else {}
				}
			}
		}
		.key_down {
			if app.placement_mode {
				if e.key_code == .r {
					if e.modifiers & 1 == 1 { // shift: 1<<0
						app.selected_ori = match app.selected_ori {
							north { west }
							east { north }
							south { east }
							west { south }
							else { north }
						}
					} else {
						app.selected_ori = match app.selected_ori {
							north { east }
							east { south }
							south { west }
							west { north }
							else { north }
						}
					}
				}
			}

			if app.solo_menu {
				if e.key_code == .backspace {
					app.text_input = app.text_input#[..-1]
				}
			} else if app.load_gate_mode {
				if e.key_code == .backspace {
					app.text_input = app.text_input#[..-1]
				}
			} else if app.keyinput_mode {
			} else if app.save_gate_mode {
				if e.key_code == .backspace {
					app.text_input = app.text_input#[..-1]
				}
			} else {
				match e.key_code {
					.escape {}
					else {}
				}
				match e.key_code {
					.z, .w, .up { app.cam_y -= 1 }
					.s, .down { app.cam_y += 1 }
					.d, .right { app.cam_x += 1 }
					.a, .q, .left { app.cam_x -= 1 }
					else {}
				}
			}
		}
		else {}
	}
	if e.char_code != 0 && e.char_code != 8 { // nothing, backspace
		if app.solo_menu {
			app.text_input += u8(e.char_code).ascii_str()
		} else if app.load_gate_mode {
			app.text_input += u8(e.char_code).ascii_str()
		} else if app.keyinput_mode {
			if app.tmp_pos_x == u32(-1) || app.tmp_pos_y == u32(-1) { // defensive: prevent map border
				for pos in app.key_pos[u8(e.char_code)] {
					i := app.forced_states.index(pos)
					if i == -1 {
						app.forced_states << pos
					} else {
						app.forced_states.delete(i)
					}
				}
			} else {
				if _ := app.key_pos[u8(e.char_code)] {
					app.key_pos[u8(e.char_code)] << Coo{app.tmp_pos_x, app.tmp_pos_y}
				} else {
					app.key_pos[u8(e.char_code)] = [
						Coo{app.tmp_pos_x, app.tmp_pos_y},
					]
				}
			}
			app.tmp_pos_x = u32(-1)
			app.tmp_pos_y = u32(-1)
		} else if app.save_gate_mode {
			app.text_input += u8(e.char_code).ascii_str()
		} else {
			if e.char_code == `r` {
				app.tile_size += 1
			} else if e.char_code == `t` && app.tile_size > 1 {
				app.tile_size -= 1
			}
		}
	}
	if app.mouse_down {
		if app.comp_running {
			if app.placement_mode {
				if mouse_x <= app.ui * ui_width {
				} else {
					if e.mouse_button == .middle && !app.place_down {
						app.move_cam()
					} else if !app.move_down {
						if !app.place_down {
							app.place_down = true
							app.place_start_x = u32(app.cam_x + mouse_x / app.tile_size)
							app.place_start_y = u32(app.cam_y + mouse_y / app.tile_size)
							app.place_end_x = u32(app.cam_x + mouse_x / app.tile_size)
							app.place_end_y = u32(app.cam_y + mouse_y / app.tile_size)
						} else {
							app.place_end_x = u32(app.cam_x + mouse_x / app.tile_size)
							app.place_end_y = u32(app.cam_y + mouse_y / app.tile_size)
						}
						x_diff := app.place_start_x - app.place_end_x
						y_diff := app.place_start_y - app.place_end_y
						if x_diff * x_diff >= y_diff * y_diff {
							app.place_end_y = app.place_start_y
						} else {
							app.place_end_x = app.place_start_x
						}
					}
				}
			} else if app.selection_mode {
				if mouse_x <= app.ui * ui_width {
				} else {
					if e.mouse_button == .left {
						app.select_start_x = u32(app.cam_x + mouse_x / app.tile_size)
						app.select_start_y = u32(app.cam_y + mouse_y / app.tile_size)
					} else if e.mouse_button == .right {
						app.select_end_x = u32(app.cam_x + mouse_x / app.tile_size)
						app.select_end_y = u32(app.cam_y + mouse_y / app.tile_size)
					} else if e.mouse_button == .middle {
						app.move_cam()
					}
				}
			} else if app.paste_mode {
				if e.mouse_button == .middle {
					app.move_cam()
				}
			} else if app.load_gate_mode {
				if e.mouse_button == .middle {
					app.move_cam()
				}
			} else if app.save_gate_mode {
				if e.mouse_button == .middle {
					app.move_cam()
				}
			} else if app.keyinput_mode {
				if e.mouse_button == .middle {
					app.move_cam()
				}
			} else if app.edit_mode {
				if e.mouse_button == .middle {
					app.move_cam()
				}
			} else {
				if mouse_x <= app.ui * ui_width {
				} else {
					app.move_cam()
				}
			}
		}
	}
}

fn (mut app App) finish_move_cam() {
	if app.move_down {
		app.move_down = false
		app.cam_x = app.cam_x - ((app.e.mouse_x - app.click_x) / app.tile_size)
		app.cam_y = app.cam_y - ((app.e.mouse_y - app.click_y) / app.tile_size)
		app.click_x = 0
		app.click_y = 0
		app.drag_x = 0
		app.drag_y = 0
	}
}

fn (mut app App) move_cam() {
	if !app.move_down {
		app.click_x = app.e.mouse_x
		app.click_y = app.e.mouse_y
	}
	app.drag_x = app.e.mouse_x
	app.drag_y = app.e.mouse_y
	app.move_down = true
}

// logic

enum Elem as u8 {
	not      // 00
	diode    // 01
	on       // 10
	wire     // 11
	crossing // 111...111
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
	// eprintln('Crashed: see the logs')
	eprintln(message)
	print_backtrace()
	exit(1)
}

fn (mut app App) nice_print(id u64) {
	rid := id & rid_mask
	print('id: ${id:064b} rid: ${rid} ')
	if id == elem_crossing_bits {
		println('Crossing')
	} else {
		match id & elem_type_mask {
			elem_wire_bits {
				w := app.wires[rid]
				println('Wire state: ${app.w_states[0][rid]},${app.w_states[1][rid]} inps: ${w.inps.map('${it:064b}')} outs: ${w.outs.map('${it:064b}')} cable_coords: ${w.cable_coords} cable_chunk_i: ${w.cable_chunk_i}')
			}
			elem_not_bits {
				print('Not ')
				n := app.nots[rid]
				x_c := n.x & chunk_bitmask
				y_c := n.y & chunk_bitmask
				chunk_i := app.get_chunkmap_idx_at_coords(n.x, n.y)
				chunkmap := &app.map[chunk_i].id_map
				match unsafe { chunkmap[x_c * chunk_size + y_c] } & ori_mask {
					north { print('north ') }
					south { print('south ') }
					east { print('east ') }
					west { print('west ') }
					else {}
				}
				println('${app.n_states[0][rid]},${app.n_states[1][rid]} x: ${n.x} y: ${n.y} inp: ${n.inp:064b}')
			}
			elem_diode_bits {
				print('Diode ')
				d := app.diodes[rid]
				x_c := d.x & chunk_bitmask
				y_c := d.y & chunk_bitmask
				chunk_i := app.get_chunkmap_idx_at_coords(d.x, d.y)
				chunkmap := &app.map[chunk_i].id_map
				match unsafe { chunkmap[x_c * chunk_size + y_c] } & ori_mask {
					north { print('north ') }
					south { print('south ') }
					east { print('east ') }
					west { print('west ') }
					else {}
				}
				println('${app.d_states[0][rid]},${app.d_states[1][rid]} x: ${d.x} y: ${d.y} inp: ${d.inp:064b}')
			}
			elem_on_bits {
				println('On')
			}
			else {
				app.log_quit('${@LOCATION} should not get into this else')
			}
		}
	}
}

enum Log {
	warn
	err
	info
}

fn (mut app App) log(message string, log_type Log) {
	mut f := os.open_append(logs_path) or { // TODO: too slow for the main thread?
		println('LOG: ${log_type} ${message}\n${err}')
		return
	}
	f.write_string('LOG: ${log_type} ${message}\n') or {
		println('LOG: ${log_type} ${message}\n${err}')
	}
	f.close()
	// x2 because size is the height of the char and the width of the char is size/2
	app.log = message.wrap(width: 2 * log_width / log_cfg.size).split('\n')
	app.log_border = match log_type {
		.warn { gg.Color{200, 200, 0, 255} }
		.err { gg.Color{200, 0, 0, 255} }
		.info { gg.Color{0, 200, 0, 255} }
	}
	app.log_timer = 180
}

struct PlaceInstruction {
mut:
	elem        Elem
	orientation u8
	// relative coos to the selection/gate
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
	app.comp_alive = true
	mut cycle_end := i64(0)
	mut now := i64(0)
	for app.comp_running {
		for pos in app.forced_states {
			app.set_elem_state_by_pos(pos.x, pos.y)
		}
		cycle_end = time.now().unix_nano() + i64(1_000_000_000.0 / f32(app.nb_updates)) - i64(app.avg_update_time) // nanosecs
		mut done := []int{}
		for i, todo in app.todo {
			now = time.now().unix_nano()
			if now < cycle_end || i == 0 {
				match todo.task {
					.save_map {
						mut failed := false
						app.save_map(todo.name) or {
							app.log('save map: ${err}', .err)
							failed = true
						}
						if !failed {
							app.log('Map saved successfully', .info)
						}
					}
					.removal {
						app.removal(todo.x, todo.y, todo.x_end, todo.y_end)
					}
					.paste {
						app.paste(todo.x, todo.y)
					}
					.load_gate {
						app.load_gate_to_copied(todo.name) or {
							app.copied = []
							app.log('load gate to copied: ${err}', .err)
						}
					}
					.save_gate {
						app.save_copied(todo.name) or { app.log('save copied: ${err}', .err) }
					}
					.place {
						app.placement(todo.x, todo.y, todo.x_end, todo.y_end)
					}
					.rotate {
						if todo.name[0] == `r` {
							app.rotate_copied_right()
						} else {
							app.rotate_copied_left()
						}
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
						mut failed := false
						app.save_map(todo.name) or {
							app.log('save map: ${err}', .err)
							failed = true
						}
						if !failed {
							app.log('Map saved successfully', .info)
						}
						app.comp_running = false
						app.clear_server_state()
						app.back_to_main_menu()
					}
				}
				done << i
			} else {
				break
			}
		}
		if app.comp_running {
			for i in done.reverse() {
				app.todo.delete(i)
			}
			now = time.now().unix_nano()
			if app.todo.len == 0 && cycle_end - now >= 10000 { // 10micro sec
				time.sleep((cycle_end - now) * time.nanosecond)
			}

			now = time.now().unix_nano()
			if !app.pause && app.comp_running {
				app.update_cycle()
			}
			app.avg_update_time = f32(time.now().unix_nano() - now) * 0.1 +
				0.9 * app.avg_update_time
		} else {
			app.avg_update_time = 0.0
		}
	}
	app.comp_alive = false
}

fn (mut app App) save_copied(name_ string) ! {
	mut name := name_
	if os.exists(gates_path) {
		for os.exists(gates_path + name) {
			name += 'New'
		}
		mut f := os.open_file(gates_path + name, 'wb')! // 'wb' because on windows writing 10 to a file translates to 0D 0A 00 00 00 because 0A is new line and 0D carriage return in text mode
		f.write_raw(u64(1))! // version 1
		for p in app.copied {
			f.write_raw(u8(p.elem))!
			f.write_raw(p.orientation)!
			f.write_raw(p.rel_x)!
			f.write_raw(p.rel_y)!
		}
		f.close()
	}
}

fn (mut app App) load_map(map_name string) ! {
	if os.exists(maps_path) {
		mut f := os.open(maps_path + map_name)!
		version := f.read_raw[u32]()!
		assert version == 0

		map_len := int(f.read_raw[i64]()!)
		app.map = []Chunk{cap: map_len}
		for _ in 0 .. map_len {
			mut new_c := Chunk{
				x:      f.read_raw[u32]()!
				y:      f.read_raw[u32]()!
				id_map: []u64{len: chunk_size * chunk_size}
			}
			f.read_into_ptr(new_c.id_map.data, chunk_size * chunk_size * int(sizeof(u64)))!
			app.map << new_c
		}

		app.nb_updates = f.read_raw[i32]()!

		app.actual_state = f.read_raw[i32]()!

		nots_len := int(f.read_raw[i64]()!)
		app.nots = []Nots{cap: nots_len}
		for _ in 0 .. nots_len {
			mut new_n := Nots{
				chunk_i: f.read_raw[i64]()!
				inp:     f.read_raw[u64]()!
				x:       f.read_raw[u32]()!
				y:       f.read_raw[u32]()!
			}
			app.nots << new_n
		}
		app.n_states[app.actual_state] = []bool{len: int(nots_len)} // to have an array in a good shape
		f.read_into_ptr(app.n_states[app.actual_state].data, nots_len * int(sizeof(bool)))!
		app.n_states[(app.actual_state + 1) % 2] = []bool{len: int(nots_len)}

		dead_nots_len := int(f.read_raw[i64]()!)
		app.dead_nots = []u64{len: dead_nots_len}
		f.read_into_ptr(app.dead_nots.data, dead_nots_len * int(sizeof(u64)))!
		app.dead_nots_lower = f.read_raw[i64]()!

		diodes_len := int(f.read_raw[i64]()!)
		app.diodes = []Diode{cap: diodes_len}
		for _ in 0 .. diodes_len {
			mut new_d := Diode{
				chunk_i: f.read_raw[i64]()!
				inp:     f.read_raw[u64]()!
				x:       f.read_raw[u32]()!
				y:       f.read_raw[u32]()!
			}
			app.diodes << new_d
		}
		app.d_states[app.actual_state] = []bool{len: int(diodes_len)}
		f.read_into_ptr(app.d_states[app.actual_state].data, diodes_len * int(sizeof(bool)))!
		app.d_states[(app.actual_state + 1) % 2] = []bool{len: diodes_len}

		dead_diodes_len := int(f.read_raw[i64]()!)
		app.dead_diodes = []u64{len: dead_diodes_len}
		f.read_into_ptr(app.dead_diodes.data, dead_diodes_len * int(sizeof(u64)))!
		app.dead_diodes_lower = f.read_raw[i64]()!

		wires_len := int(f.read_raw[i64]()!)
		app.wires = []Wire{cap: wires_len}
		for _ in 0 .. wires_len {
			inps_len := int(f.read_raw[i64]()!)
			outs_len := int(f.read_raw[i64]()!)
			cable_coords_len := int(f.read_raw[i64]()!)
			cable_chunk_i_len := int(f.read_raw[i64]()!)
			mut new_w := Wire{
				inps:          []u64{len: inps_len}
				outs:          []u64{len: outs_len}
				cable_coords:  []Coo{cap: cable_coords_len}
				cable_chunk_i: []i64{len: cable_chunk_i_len}
			}
			f.read_into_ptr(new_w.inps.data, inps_len * int(sizeof(u64)))!
			f.read_into_ptr(new_w.outs.data, outs_len * int(sizeof(u64)))!

			for _ in 0 .. cable_coords_len {
				new_w.cable_coords << Coo{
					x: f.read_raw[u32]()!
					y: f.read_raw[u32]()!
				}
			}
			f.read_into_ptr(new_w.cable_chunk_i.data, cable_chunk_i_len * int(sizeof(i64)))!
			app.wires << new_w
		}
		app.w_states[app.actual_state] = []bool{len: int(wires_len)}
		f.read_into_ptr(app.w_states[app.actual_state].data, wires_len * int(sizeof(bool)))!
		app.w_states[(app.actual_state + 1) % 2] = []bool{len: wires_len}

		dead_wires_len := int(f.read_raw[i64]()!)
		app.dead_wires = []u64{len: dead_wires_len}
		f.read_into_ptr(app.dead_wires.data, dead_wires_len * int(sizeof(u64)))!
		app.dead_wires_lower = f.read_raw[i64]() or { panic(err) }

		forced_states_len := int(f.read_raw[i64]()!)
		app.forced_states = []Coo{cap: forced_states_len}
		for _ in 0 .. forced_states_len {
			app.forced_states << Coo{f.read_raw[u32]()!, f.read_raw[u32]()!}
		}

		key_pos_len := int(f.read_raw[i64]()!)
		for _ in 0 .. key_pos_len {
			key := f.read_raw[u8]()!
			coords_len := int(f.read_raw[i64]()!)
			app.key_pos[key] = []Coo{cap: coords_len}
			for _ in 0 .. coords_len {
				app.key_pos[key] << Coo{f.read_raw[u32]()!, f.read_raw[u32]()!}
			}
		}

		colorchips_len := int(f.read_raw[i64]()!)
		app.colorchips = []
		for _ in 0 .. colorchips_len {
			mut new_cc := ColorChip{
				x: f.read_raw[u32]()!
				y: f.read_raw[u32]()!
				w: f.read_raw[u32]()!
				h: f.read_raw[u32]()!
			}
			colors_len := int(f.read_raw[i64]()!)
			for _ in 0 .. colors_len {
				new_cc.colors << gg.Color{f.read_raw[u8]()!, f.read_raw[u8]()!, f.read_raw[u8]()!, 255}
			}
			inputs_len := f.read_raw[i64]()!
			for _ in 0 .. inputs_len {
				new_cc.inputs << Coo{f.read_raw[u32]()!, f.read_raw[u32]()!}
			}
			app.colorchips << new_cc
		}

		chunk_cache_len := int(f.read_raw[i64]()!)
		for _ in 0 .. chunk_cache_len {
			app.chunk_cache[f.read_raw[u64]()!] = f.read_raw[i32]()!
		}

		f.close()
	}
}

fn (mut app App) save_map(map_name string) ! {
	// u32(version)
	//
	// i64(app.map.len)
	// for each chunk:
	// 	chunk.x u32 chunk.y u32
	// 	chunk's content []u64
	//
	// nb_updates i32
	//
	// actual_state i32 (which array)
	//
	// i64(app.nots.len)
	// all the nots (their data)
	// 	chunk_i i64 inp u64 x u32 y u32
	// nots' state array [actual_state][]bool
	//
	// i64(dead_nots.len)
	// all the dead nots []u64
	// dead_nots_lower i64
	//
	// i64(app.diodes.len)
	// all the diodes (their data)
	// 	chunk_i i64 inp u64 x u32 y u32
	// diode's state array [actual_state][]bool
	//
	// i64(dead_diodes.len)
	// all the dead diodes []u64
	// dead_diodes_lower i64
	//
	// i64(app.wires.len)
	// for each wire:
	//	i64(wire.inps.len)
	//	i64(wire.outs.len)
	//	i64(wire.cable_coords.len)
	//	i64(wire.cable_chunk_i.len)
	//	all the inputs []u64
	//	all the outputs []u64
	// 	for all the cables:
	// 		cable.x u32 cable.y u32
	// 	for all the cables:
	//	 	cable_chunk_i i64
	// wire's state array [actual_state][]bool
	//
	// i64(dead_wires.len)
	// all the dead wires []u64
	// dead_wires_lower i64
	//
	// i64(app.forced_states.len)
	// forced_states []Coo u32 u32
	//
	// i64(app.key_pos.keys().len)
	// for each key:
	// 	key u8
	// 	app.key_pos[key].len i64
	//	every Coo in app.key_pos[key] x u32 y u32
	//
	// i64(app.colorchips.len)
	// for each cc:
	// 	x u32 y u32 w u32 h u32
	//	i64(cc.colors.len)
	//	colors []gg.Color r g b u8 u8 u8
	//	i64(cc.inputs.len)
	//	inputs []Coo x u32 y u32
	//
	// i64(app.chunk_cache.values().len)
	// for each value
	// 	u64 value
	//	i32 associated index

	mut file := os.open_file(maps_path + map_name, 'wb') or { // TODO: open a tmp file, and then copy it to the true one
		app.log('${@LOCATION}: ${err}', .err)
		return
	}
	defer {
		file.close()
	}
	mut offset := u64(0)

	save_version := u32(0) // must be careful when V changes of int size, especially for array lenghts
	file.write_raw_at(save_version, offset) or {
		app.log('${@LOCATION}: ${err}', .err)
		return
	}
	offset += sizeof(u32)

	file.write_raw_at(i64(app.map.len), offset) or {
		app.log('${@LOCATION}: ${err}', .err)
		return
	}
	offset += sizeof(i64)
	for mut chunk in app.map {
		file.write_raw_at(chunk.x, offset) or {
			app.log('${@LOCATION}: ${err}', .err)
			return
		}
		offset += sizeof(u32)
		file.write_raw_at(chunk.y, offset) or {
			app.log('${@LOCATION}: ${err}', .err)
			return
		}
		offset += sizeof(u32)
		unsafe {
			file.write_ptr_at(chunk.id_map.data, chunk_size * chunk_size * int(sizeof(u64)),
				offset)
		}
		offset += chunk_size * chunk_size * sizeof(u64)
	}

	file.write_raw_at(i32(app.nb_updates), offset) or {
		app.log('${@LOCATION}: ${err}', .err)
		return
	}
	offset += sizeof(i32)

	file.write_raw_at(i32(app.actual_state), offset) or {
		app.log('${@LOCATION}: ${err}', .err)
		return
	}
	offset += sizeof(i32)

	file.write_raw_at(i64(app.nots.len), offset) or {
		app.log('${@LOCATION}: ${err}', .err)
		return
	}
	offset += sizeof(i64)
	for n in app.nots {
		file.write_raw_at(n.chunk_i, offset) or {
			app.log('${@LOCATION}: ${err}', .err)
			return
		}
		offset += sizeof(i64)
		file.write_raw_at(n.inp, offset) or {
			app.log('${@LOCATION}: ${err}', .err)
			return
		}
		offset += sizeof(u64)
		file.write_raw_at(n.x, offset) or {
			app.log('${@LOCATION}: ${err}', .err)
			return
		}
		offset += sizeof(u32)
		file.write_raw_at(n.y, offset) or {
			app.log('${@LOCATION}: ${err}', .err)
			return
		}
		offset += sizeof(u32)
	}
	unsafe {
		file.write_ptr_at(app.n_states[app.actual_state].data, app.nots.len * int(sizeof(bool)),
			offset)
	}
	offset += u64(app.nots.len) * sizeof(bool)

	file.write_raw_at(i64(app.dead_nots.len), offset) or {
		app.log('${@LOCATION}: ${err}', .err)
		return
	}
	offset += sizeof(i64)
	unsafe {
		file.write_ptr_at(app.dead_nots.data, app.nots.len * int(sizeof(u64)), offset)
	}
	offset += u64(app.dead_nots.len) * sizeof(u64)
	file.write_raw_at(i64(app.dead_nots_lower), offset) or {
		app.log('${@LOCATION}: ${err}', .err)
		return
	}
	offset += sizeof(i64)

	file.write_raw_at(i64(app.diodes.len), offset) or {
		app.log('${@LOCATION}: ${err}', .err)
		return
	}
	offset += sizeof(i64)
	for d in app.diodes {
		file.write_raw_at(d.chunk_i, offset) or {
			app.log('${@LOCATION}: ${err}', .err)
			return
		}
		offset += sizeof(i64)
		file.write_raw_at(d.inp, offset) or {
			app.log('${@LOCATION}: ${err}', .err)
			return
		}
		offset += sizeof(u64)
		file.write_raw_at(d.x, offset) or {
			app.log('${@LOCATION}: ${err}', .err)
			return
		}
		offset += sizeof(u32)
		file.write_raw_at(d.y, offset) or {
			app.log('${@LOCATION}: ${err}', .err)
			return
		}
		offset += sizeof(u32)
	}
	unsafe {
		file.write_ptr_at(app.d_states[app.actual_state].data, app.diodes.len * int(sizeof(bool)),
			offset)
	}
	offset += u64(app.diodes.len) * sizeof(bool)

	file.write_raw_at(i64(app.dead_diodes.len), offset) or {
		app.log('${@LOCATION}: ${err}', .err)
		return
	}
	offset += sizeof(i64)
	unsafe {
		file.write_ptr_at(app.dead_diodes.data, app.diodes.len * int(sizeof(u64)), offset)
	}
	offset += u64(app.dead_diodes.len) * sizeof(u64)
	file.write_raw_at(i64(app.dead_diodes_lower), offset) or {
		app.log('${@LOCATION}: ${err}', .err)
		return
	}
	offset += sizeof(i64)

	file.write_raw_at(i64(app.wires.len), offset) or {
		app.log('${@LOCATION}: ${err}', .err)
		return
	}
	offset += sizeof(i64)
	for wire in app.wires {
		file.write_raw_at(i64(wire.inps.len), offset) or {
			app.log('${@LOCATION}: ${err}', .err)
			return
		}
		offset += sizeof(i64)
		file.write_raw_at(i64(wire.outs.len), offset) or {
			app.log('${@LOCATION}: ${err}', .err)
			return
		}
		offset += sizeof(i64)
		file.write_raw_at(i64(wire.cable_coords.len), offset) or {
			app.log('${@LOCATION}: ${err}', .err)
			return
		}
		offset += sizeof(i64)
		file.write_raw_at(i64(wire.cable_chunk_i.len), offset) or {
			app.log('${@LOCATION}: ${err}', .err)
			return
		}
		offset += sizeof(i64)

		unsafe { file.write_ptr_at(wire.inps.data, wire.inps.len * int(sizeof(u64)), offset) }
		offset += u64(wire.inps.len) * sizeof(u64)
		unsafe { file.write_ptr_at(wire.outs.data, wire.outs.len * int(sizeof(u64)), offset) }
		offset += u64(wire.outs.len) * sizeof(u64)

		for cable in wire.cable_coords {
			file.write_raw_at(cable.x, offset) or {
				app.log('${@LOCATION}: ${err}', .err)
				return
			}
			offset += sizeof(u32)
			file.write_raw_at(cable.y, offset) or {
				app.log('${@LOCATION}: ${err}', .err)
				return
			}
			offset += sizeof(u32)
		}
		unsafe {
			file.write_ptr_at(wire.cable_chunk_i.data, wire.cable_chunk_i.len * int(sizeof(i64)),
				offset)
		}
		offset += u64(wire.cable_chunk_i.len) * sizeof(i64)
	}
	unsafe {
		file.write_ptr_at(app.w_states[app.actual_state].data, app.wires.len * int(sizeof(bool)),
			offset)
	}
	offset += u64(app.wires.len) * sizeof(bool)

	file.write_raw_at(i64(app.dead_wires.len), offset) or {
		app.log('${@LOCATION}: ${err}', .err)
		return
	}
	offset += sizeof(i64)
	unsafe {
		file.write_ptr_at(app.dead_wires.data, app.wires.len * int(sizeof(u64)), offset)
	}
	offset += u64(app.dead_wires.len) * sizeof(u64)
	file.write_raw_at(i64(app.dead_wires_lower), offset) or {
		app.log('${@LOCATION}: ${err}', .err)
		return
	}
	offset += sizeof(i64)

	file.write_raw_at(i64(app.forced_states.len), offset) or {
		app.log('${@LOCATION}: ${err}', .err)
		return
	}
	offset += sizeof(i64)
	for pos in app.forced_states {
		file.write_raw_at(pos.x, offset) or {
			app.log('${@LOCATION}: ${err}', .err)
			return
		}
		offset += sizeof(u32)
		file.write_raw_at(pos.y, offset) or {
			app.log('${@LOCATION}: ${err}', .err)
			return
		}
		offset += sizeof(u32)
	}

	file.write_raw_at(i64(app.key_pos.keys().len), offset) or {
		app.log('${@LOCATION}: ${err}', .err)
		return
	}
	offset += sizeof(i64)
	for k, v in app.key_pos {
		file.write_raw_at(k, offset) or {
			app.log('${@LOCATION}: ${err}', .err)
			return
		}
		offset += sizeof(u8)
		file.write_raw_at(i64(v.len), offset) or {
			app.log('${@LOCATION}: ${err}', .err)
			return
		}
		offset += sizeof(i64)
		for c in v {
			file.write_raw_at(c.x, offset) or {
				app.log('${@LOCATION}: ${err}', .err)
				return
			}
			offset += sizeof(u32)
			file.write_raw_at(c.y, offset) or {
				app.log('${@LOCATION}: ${err}', .err)
				return
			}
			offset += sizeof(u32)
		}
	}

	file.write_raw_at(i64(app.colorchips.len), offset) or {
		app.log('${@LOCATION}: ${err}', .err)
		return
	}
	offset += sizeof(i64)
	for cc in app.colorchips {
		file.write_raw_at(cc.x, offset) or {
			app.log('${@LOCATION}: ${err}', .err)
			return
		}
		offset += sizeof(u32)
		file.write_raw_at(cc.y, offset) or {
			app.log('${@LOCATION}: ${err}', .err)
			return
		}
		offset += sizeof(u32)
		file.write_raw_at(cc.w, offset) or {
			app.log('${@LOCATION}: ${err}', .err)
			return
		}
		offset += sizeof(u32)
		file.write_raw_at(cc.h, offset) or {
			app.log('${@LOCATION}: ${err}', .err)
			return
		}
		offset += sizeof(u32)

		file.write_raw_at(i64(cc.colors.len), offset) or {
			app.log('${@LOCATION}: ${err}', .err)
			return
		}
		offset += sizeof(i64)
		for color in cc.colors {
			file.write_raw_at(color.r, offset) or {
				app.log('${@LOCATION}: ${err}', .err)
				return
			}
			offset += sizeof(u8)
			file.write_raw_at(color.g, offset) or {
				app.log('${@LOCATION}: ${err}', .err)
				return
			}
			offset += sizeof(u8)
			file.write_raw_at(color.b, offset) or {
				app.log('${@LOCATION}: ${err}', .err)
				return
			}
			offset += sizeof(u8)
		}

		file.write_raw_at(i64(cc.inputs.len), offset) or {
			app.log('${@LOCATION}: ${err}', .err)
			return
		}
		offset += sizeof(i64)
		for i in cc.inputs {
			file.write_raw_at(i.x, offset) or {
				app.log('${@LOCATION}: ${err}', .err)
				return
			}
			offset += sizeof(u32)
			file.write_raw_at(i.y, offset) or {
				app.log('${@LOCATION}: ${err}', .err)
				return
			}
			offset += sizeof(u32)
		}
	}

	file.write_raw_at(i64(app.chunk_cache.keys().len), offset) or {
		app.log('${@LOCATION}: ${err}', .err)
		return
	}
	offset += sizeof(i64)
	for k, v in app.chunk_cache {
		file.write_raw_at(k, offset) or {
			app.log('${@LOCATION}: ${err}', .err)
			return
		}
		offset += sizeof(u64)
		file.write_raw_at(v, offset) or {
			app.log('${@LOCATION}: ${err}', .err)
			return
		}
		offset += sizeof(i32)
	}
}

struct OldPlaceInstruction {
mut:
	elem        u32
	orientation u8
	rel_x       i32
	rel_y       i32
}

fn (mut app App) old_load_gate_to_copied(gate_name string) ! {
	mut f := os.open(gates_path + gate_name)!
	mut read_n := u32(0)
	size := os.inode(gates_path + gate_name).size
	app.copied = []
	mut oplace := OldPlaceInstruction{}
	mut place := PlaceInstruction{}
	for read_n * sizeof(OldPlaceInstruction) < size {
		f.read_struct_at(mut oplace, read_n * sizeof(OldPlaceInstruction))!
		place.elem = Elem.from(oplace.elem)!
		place.orientation = oplace.orientation
		place.rel_x = oplace.rel_x
		place.rel_y = oplace.rel_y
		app.copied << place
		read_n += 1
	}
	f.close()
}

fn (mut app App) load_gate_to_copied(gate_name string) ! {
	if gate_name#[0..3] == 'old' {
		app.old_load_gate_to_copied(gate_name)!
	} else {
		mut f := os.open(gates_path + gate_name)!
		mut read_n := u32(0)
		version := f.read_raw[u64]()!
		app.copied = []
		mut place := PlaceInstruction{}
		mut load := []PlaceInstruction{}
		size := os.inode(gates_path + gate_name).size - 8 // for the version
		if version == 0 {
			app.log('Load gate: version number ${version}', .info)
			for read_n * 12 < size {
				// Change back when tcc will understand enum sizes
				e := f.read_raw[u8]()!
				place.elem = Elem.from(e)!
				place.orientation = f.read_raw[u8]()!
				_ := f.read_raw[u16]()!
				place.rel_x = f.read_raw[i32]()!
				place.rel_y = f.read_raw[i32]()!
				load << place
				read_n += 1
			}
		} else if version == 1 {
			for read_n * 10 < size {
				// Change back when tcc will understand enum sizes
				e := f.read_raw[u8]()!
				place.elem = Elem.from(e)!
				place.orientation = f.read_raw[u8]()!
				place.rel_x = f.read_raw[i32]()!
				place.rel_y = f.read_raw[i32]()!
				load << place
				read_n += 1
			}
		} else {
			app.log('Load gate: invalid version number ${version}', .warn)
		}
		app.copied = load.clone()
		f.close()
	}
}

fn (mut app App) flip_v() {
	// find size of the patern
	if app.copied.len > 0 {
		mut min_x := app.copied[0].rel_y
		mut min_y := app.copied[0].rel_x
		for mut place in app.copied {
			place.rel_y = -place.rel_y
			if min_x > place.rel_x {
				min_x = place.rel_x
			}
			if min_y > place.rel_y {
				min_y = place.rel_y
			}
			place.orientation = u8(match u64(place.orientation) {
				north >> 56 { south >> 56 }
				east >> 56 { east >> 56 }
				south >> 56 { north >> 56 }
				west >> 56 { west >> 56 }
				else { app.log_quit('invalid orientation') }
			})
		}
		for mut place in app.copied {
			place.rel_x -= min_x
			place.rel_y -= min_y
		}
	}
}

fn (mut app App) flip_h() {
	// find size of the patern
	if app.copied.len > 0 {
		mut min_x := app.copied[0].rel_y
		mut min_y := app.copied[0].rel_x
		for mut place in app.copied {
			place.rel_x = -place.rel_x
			if min_x > place.rel_x {
				min_x = place.rel_x
			}
			if min_y > place.rel_y {
				min_y = place.rel_y
			}
			place.orientation = u8(match u64(place.orientation) {
				north >> 56 { north >> 56 }
				east >> 56 { west >> 56 }
				south >> 56 { south >> 56 }
				west >> 56 { east >> 56 }
				else { app.log_quit('invalid orientation') }
			})
		}
		for mut place in app.copied {
			place.rel_x -= min_x
			place.rel_y -= min_y
		}
	}
}

fn (mut app App) rotate_copied_left() {
	if app.copied.len > 0 {
		mut max_x := i32(0)
		// find size of the patern
		for place in app.copied {
			if place.rel_x > max_x {
				max_x = place.rel_x
			}
		}

		mut min_x := app.copied[0].rel_y
		mut min_y := app.copied[0].rel_x
		for mut place in app.copied { // matrix rotation by 90 deg
			tmp_x := place.rel_x
			place.rel_x = place.rel_y
			place.rel_y = max_x - tmp_x - 1
			if min_x > place.rel_x {
				min_x = place.rel_x
			}
			if min_y > place.rel_y {
				min_y = place.rel_y
			}
			place.orientation = u8(match u64(place.orientation) {
				north >> 56 { west >> 56 }
				east >> 56 { north >> 56 }
				south >> 56 { east >> 56 }
				west >> 56 { south >> 56 }
				else { app.log_quit('invalid orientation') }
			})
		}
		for mut place in app.copied {
			place.rel_x -= min_x
			place.rel_y -= min_y
		}
	}
}

fn (mut app App) rotate_copied_right() {
	if app.copied.len > 0 {
		mut max_y := i32(0)
		// find size of the patern
		for place in app.copied {
			if place.rel_y > max_y {
				max_y = place.rel_y
			}
		}

		mut min_x := app.copied[0].rel_y
		mut min_y := app.copied[0].rel_x
		for mut place in app.copied { // matrix rotation by -90 deg
			tmp_y := place.rel_y
			place.rel_y = place.rel_x
			place.rel_x = max_y - tmp_y - 1
			if min_x > place.rel_x {
				min_x = place.rel_x
			}
			if min_y > place.rel_y {
				min_y = place.rel_y
			}
			place.orientation = u8(match u64(place.orientation) {
				north >> 56 { east >> 56 }
				east >> 56 { south >> 56 }
				south >> 56 { west >> 56 }
				west >> 56 { north >> 56 }
				else { app.log_quit('invalid orientation') }
			})
		}
		for mut place in app.copied {
			place.rel_x -= min_x
			place.rel_y -= min_y
		}
	}
}

// Will be used?
fn (mut app App) gate_unit_tests(x u32, y u32, square_size int) {
	size := u32(square_size) // we dont know the size of the gates that will be placed, 100 should be okay, same as below
	cycles := square_size // we dont know in how much cycles the bug will happen, needs to match the amount in the fuzz testing because the unit tests will come from there
	app.removal(x, y, x + size, y + size)
	gates: for gate_path in os.ls('test_gates/') or {
		app.log('Listing the test gates: ${err}', .err)
		return
	} {
		app.load_gate_to_copied('test_gates/' + gate_path) or {
			app.log('FAIL: cant load the gate: test_gates/${gate_path}, ${err}', .err)
			app.copied = []
			continue
		}
		app.paste(x, y)
		for _ in 0 .. cycles {
			app.update_cycle()
			x_err, y_err, str_err := app.test_validity(x, y, x + size, y + size, true,
				false)
			if str_err != '' {
				app.log('FAIL: (validity) ${str_err}', .err)
				println('TODO:')
				println(x_err)
				println(y_err)
				// TODO: show the coords on screen (tp to the right place & color the square)
				continue gates
			}
		}
		app.removal(x, y, x + size, y + size)
	}
}

fn (mut app App) paste(x_start u32, y_start u32) {
	old_item := app.selected_item
	old_ori := app.selected_ori
	for place in app.copied {
		app.selected_item = place.elem
		app.selected_ori = u64(place.orientation) << 56
		app.placement(u32(i64(place.rel_x) + i64(x_start)), u32(i64(place.rel_y) + i64(y_start)),
			u32(i64(place.rel_x) + i64(x_start)), u32(i64(place.rel_y) + i64(y_start)))
	}
	app.selected_ori = old_ori
	app.selected_item = old_item
}

fn (mut app App) is_id_dead(id u64) bool {
	match id & elem_type_mask {
		elem_not_bits {
			return app.nots[id & rid_mask].x == invalid_coo
		}
		elem_diode_bits {
			return app.diodes[id & rid_mask].x == invalid_coo
		}
		elem_wire_bits {
			return app.wires[id & rid_mask].cable_coords[0].x == invalid_coo
		}
		else {}
	}
	return false
}

fn (mut app App) test_validity(_x_start u32, _y_start u32, _x_end u32, _y_end u32, check_state bool, big_wire_test bool) (u32, u32, string) {
	// eprintln('test_validity {')
	// check all the elems in the rectangle to see if their state / data is valid
	// input/output id (ajdacent tiles)
	// current state (depending on the input)
	// for the wires : check if adj_wires in the same wire

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
	mut chunk_i := app.get_chunkmap_idx_at_coords(x_start, y_start)
	mut chunkmap := &app.map[chunk_i].id_map
	mut last_cm_x := x_start
	mut last_cm_y := y_start
	// eprintln('\tcheck wires {')
	for w in app.wires {
		if w.cable_coords[0].x != invalid_coo {
			if w.cable_coords.len != w.cable_chunk_i.len {
				return w.cable_coords[0].x, w.cable_coords[0].y, 'problem: not same size ${w.cable_coords.len} != ${w.cable_chunk_i.len}'
			}
			for cc in w.cable_coords {
				if cc.x & chunk_inv_bitmask != last_cm_x & chunk_inv_bitmask
					|| cc.y & chunk_inv_bitmask != last_cm_y & chunk_inv_bitmask { // inlined check_change_chunkmap
					last_cm_x = cc.x
					last_cm_y = cc.y
					chunk_i = app.get_chunkmap_idx_at_coords(cc.x, cc.y)
					chunkmap = &app.map[chunk_i].id_map
				}
				id := unsafe { chunkmap[(cc.x & chunk_bitmask) * chunk_size + cc.y & chunk_bitmask] }
				if id & elem_type_mask != elem_wire_bits {
					return cc.x, cc.y, 'problem: cable coord does not point to wire'
				}
			}
		}
	}
	// eprintln('\tcheck wires }')
	for x in x_start .. x_end + 1 {
		for y in y_start .. y_end + 1 {
			if x & chunk_inv_bitmask != last_cm_x & chunk_inv_bitmask
				|| y & chunk_inv_bitmask != last_cm_y & chunk_inv_bitmask { // inlined check_change_chunkmap
				last_cm_x = x
				last_cm_y = y
				chunk_i = app.get_chunkmap_idx_at_coords(x, y)
				chunkmap = &app.map[chunk_i].id_map
			}
			x_map := x & chunk_bitmask
			y_map := y & chunk_bitmask
			id := unsafe { chunkmap[x_map * chunk_size + y_map] }
			if id == 0x0 { // map empty
				continue
			}
			if id == elem_crossing_bits { // same bits as wires so need to be separated
				continue // do not have any state to check
			}
			// check if not dead
			if app.is_id_dead(id) {
				continue
			}
			ori := id & ori_mask
			step := match ori {
				north {
					[0, -1]!
				}
				south {
					[0, 1]!
				}
				west {
					[-1, 0]!
				}
				east {
					[1, 0]!
				}
				else {
					app.log_quit('${@LOCATION} not a valid orientation')
				}
			}

			match id & elem_type_mask {
				elem_not_bits, elem_diode_bits {
					world_inp_id := app.next_gate_id(x, y, -step[0], -step[1], ori)
					data_inp_id := app.get_input(id)
					if data_inp_id != empty_id && app.is_id_dead(data_inp_id) {
						return x, y, 'problem: Not/Diode ${id & id_mask:b} input is dead ${data_inp_id & id_mask:b} != ${world_inp_id & id_mask:b}'
					}
					if world_inp_id & id_mask != data_inp_id & id_mask {
						app.nice_print(id)
						app.nice_print(data_inp_id)
						app.nice_print(world_inp_id)
						return x, y, 'problem: Not/Diode ${id & id_mask:b} input is not the preceding gate ${data_inp_id & id_mask:b} != ${world_inp_id & id_mask:b}'
					}
					inp_old_state := app.get_elem_state_by_id(world_inp_id, 1)
					if check_state && id & elem_type_mask == elem_not_bits {
						state := app.get_elem_state_by_id(id, 0)
						if state == inp_old_state {
							app.nice_print(id)
							return x, y, 'problem: NOT did not inverse the input state ${state} ${inp_old_state}'
						}
						if (id & on_bits != 0) != state {
							app.nice_print(id)
							return x, y, 'problem: NOT is not the same on the map and in state array ${id & on_bits != 0} ${state}'
						}
					} else if check_state { // diode
						state := app.get_elem_state_by_id(id, 0)
						if state != inp_old_state {
							app.nice_print(id)
							return x, y, 'problem: Diode did not match the input state'
						}
						if (id & on_bits != 0) != state {
							app.nice_print(id)
							return x, y, 'problem: Diode is not the same on the map and in state array'
						}
					}
				}
				elem_on_bits { // do not have any data to check
				}
				elem_wire_bits {
					s_adj_id, s_is_input, _, _ := app.wire_next_gate_id_coo(x, y, 0, 1)
					n_adj_id, n_is_input, _, _ := app.wire_next_gate_id_coo(x, y, 0, -1)
					e_adj_id, e_is_input, _, _ := app.wire_next_gate_id_coo(x, y, 1, 0)
					w_adj_id, w_is_input, _, _ := app.wire_next_gate_id_coo(x, y, -1,
						0)
					wire_idx := id & rid_mask
					wire_state := app.get_elem_state_by_id(id, 0)
					if !big_wire_test {
						coo := Coo{x, y}
						count := app.wires[wire_idx].cable_coords.count(it == coo)
						if count < 1 {
							return x, y, 'problem: cable(on map) is not in cable_coords ${x} ${y} !in ${app.wires[wire_idx].cable_coords}'
						}
						if count > 1 {
							return x, y, 'problem: cable is multiple times in cable_coords'
						}
					}
					if check_state && (id & on_bits != 0) != wire_state {
						app.nice_print(id)
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
								s_old_state := app.get_elem_state_by_id(s_adj_id, 1)
								if check_state && s_old_state && !wire_state {
									return x, y, 'problem: wire ${id & rid_mask} did not match south On state'
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
								n_old_state := app.get_elem_state_by_id(n_adj_id, 1)
								if check_state && n_old_state && !wire_state {
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
								e_old_state := app.get_elem_state_by_id(e_adj_id, 1)
								if check_state && e_old_state && !wire_state {
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
								w_old_state := app.get_elem_state_by_id(w_adj_id, 1)
								if check_state && w_old_state && !wire_state {
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
	// eprintln('test_validity }')
	return 0, 0, ''
}

fn (mut app App) fuzz(_x_start u32, _y_start u32, _x_end u32, _y_end u32, p_tries u32, d_tries u32, seed []u32, check_graph bool) {
	// place random elems in a rectangle
	rand.seed(seed)

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
	for _ in 0 .. p_tries {
		x := rand.u32_in_range(x_start, x_end + 1) or { 2 }
		y := rand.u32_in_range(y_start, y_end + 1) or { 2 }
		app.selected_ori = match rand.int_in_range(0, 4) or { 0 } {
			1 { north }
			2 { south }
			3 { east }
			else { west }
		}
		elem := rand.int_in_range(0, 6) or { 0 }
		match elem {
			1 {
				app.selected_item = .not
				app.placement(x, y, x, y)
			}
			2 {
				app.selected_item = .diode
				app.placement(x, y, x, y)
			}
			3 {
				app.selected_item = .on
				app.placement(x, y, x, y)
			}
			4 {
				app.selected_item = .wire
				app.placement(x, y, x, y)
			}
			5 {
				app.selected_item = .crossing
				app.placement(x, y, x, y)
			}
			else {}
		}
		if check_graph {
			x_err, y_err, str_err := app.test_validity(x_start, y_start, x_end, y_end,
				false, false)
			if str_err != '' {
				println('Last elem: ${elem} at x:${x} y:${y}, 1=not, 2=diode, 3=on, 4=wire, 5=crossing, 0=empty')
				println('FAIL: (validity) ${str_err} ${x_err} ${y_err}')
				app.debug_view() or { continue }
				panic('FAIL: (validity) ${str_err} ${x_err} ${y_err}')
			}
		}
	}
	for _ in 0 .. d_tries {
		x := rand.u32_in_range(x_start, x_end + 1) or { 2 }
		y := rand.u32_in_range(y_start, y_end + 1) or { 2 }
		app.removal(x, y, x, y)
	}
}

// Only use it if in test file
fn (mut app App) debug_view() ! {
	app.debug_mode = true
	app.ctx = gg.new_context(
		create_window: true
		window_title:  'Not Gates'
		user_data:     app
		init_fn:       on_init
		frame_fn:      on_frame
		event_fn:      on_event
		sample_count:  0
		bg_color:      app.palette.background
		font_path:     font_path
	)
	app.init_graphics()!
	app.comp_running = true
	app.ctx.run()
}

fn (mut app App) copy(_x_start u32, _y_start u32, _x_end u32, _y_end u32) {
	// for all the elements in the rectangle
	// 	add an instruction with the info needed to place the elem later

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

	app.copied = []

	mut chunk_i := app.get_chunkmap_idx_at_coords(x_start, y_start)
	mut last_cm_x := x_start
	mut last_cm_y := y_start
	for x in x_start .. x_end + 1 {
		for y in y_start .. y_end + 1 {
			if check_change_chunkmap(last_cm_x, last_cm_y, x, y) {
				last_cm_x = x
				last_cm_y = y
				chunk_i = app.get_chunkmap_idx_at_coords(x, y)
			}
			mut chunkmap := &app.map[chunk_i].id_map
			x_map := x & chunk_bitmask
			y_map := y & chunk_bitmask
			id := unsafe { chunkmap[x_map * chunk_size + y_map] }
			if id == empty_id { // map empty
				continue
			}
			if id == elem_crossing_bits { // same bits as wires so need to be separated
				app.copied << PlaceInstruction{.crossing, u8(0), i32(x - x_start), i32(y - y_start)}
				continue
			}

			ori := id & ori_mask
			rel_x := i32(x - x_start)
			rel_y := i32(y - y_start)
			match id & elem_type_mask {
				elem_not_bits {
					app.copied << PlaceInstruction{.not, u8(ori >> 56), rel_x, rel_y}
				}
				elem_diode_bits {
					app.copied << PlaceInstruction{.diode, u8(ori >> 56), rel_x, rel_y}
				}
				elem_on_bits {
					app.copied << PlaceInstruction{.on, u8(ori >> 56), rel_x, rel_y}
				}
				elem_wire_bits {
					app.copied << PlaceInstruction{.wire, u8(0), rel_x, rel_y}
				}
				else {
					app.log_quit('${@LOCATION} should not get into this else')
				}
			}
		}
	}
}

fn (mut app App) add_dead_rid(t Elem, rid u64) {
	match t {
		.not {
			if app.dead_nots_lower > 0 {
				app.dead_nots_lower--
				app.dead_nots[app.dead_nots_lower] = rid
			} else {
				app.dead_nots << rid
			}
		}
		.diode {
			if app.dead_diodes_lower > 0 {
				app.dead_diodes_lower--
				app.dead_diodes[app.dead_diodes_lower] = rid
			} else {
				app.dead_diodes << rid
			}
		}
		.wire {
			if app.dead_wires_lower > 0 {
				app.dead_wires_lower--
				app.dead_wires[app.dead_wires_lower] = rid
			} else {
				app.dead_wires << rid
			}
		}
		.on {} // not stored
		.crossing {} // not stored
	}
}

// returns if nothing in the dead array { 0 } else { the rid of the dead elem }
fn (mut app App) get_free_dead_rid(t Elem) i64 {
	match t {
		.not {
			if app.dead_nots.len > 0 && app.dead_nots_lower < app.dead_nots.len {
				app.dead_nots_lower++
				return i64(app.dead_nots[app.dead_nots_lower - 1])
			} else {
				return 0
			}
		}
		.diode {
			if app.dead_diodes.len > 0 && app.dead_diodes_lower < app.dead_diodes.len {
				app.dead_diodes_lower++
				return i64(app.dead_diodes[app.dead_diodes_lower - 1])
			} else {
				return 0
			}
		}
		.wire {
			if app.dead_wires.len > 0 && app.dead_wires_lower < app.dead_wires.len {
				app.dead_wires_lower++
				return i64(app.dead_wires[app.dead_wires_lower - 1])
			} else {
				return 0
			}
		}
		.on {} // not stored
		.crossing {} // not stored
	}
	panic('${@LOCATION}: unexpected path ${t}')
}

fn (mut app App) removal(_x_start u32, _y_start u32, _x_end u32, _y_end u32) {
	// 1.
	// set the tile id to empty_id
	// 2.
	// remove the struct from the array
	// remove the state from the arrays (there are 2 state arrays to modify ! )
	// 3.
	// update the output/inputs fields of the adjacent elements

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

	mut chunk_i := app.get_chunkmap_idx_at_coords(x_start, y_start)
	mut last_cm_x := x_start
	mut last_cm_y := y_start
	for x in x_start .. x_end + 1 {
		for y in y_start .. y_end + 1 {
			if check_change_chunkmap(last_cm_x, last_cm_y, x, y) {
				last_cm_x = x
				last_cm_y = y
				chunk_i = app.get_chunkmap_idx_at_coords(x, y)
			}
			mut chunkmap := &app.map[chunk_i].id_map
			x_map := x & chunk_bitmask
			y_map := y & chunk_bitmask
			id := unsafe { chunkmap[x_map * chunk_size + y_map] }
			if id == empty_id { // map empty
				continue
			}
			mut x_ori, mut y_ori := match id & ori_mask {
				// Output direction
				north { 0, -1 }
				south { 0, 1 }
				east { 1, 0 }
				west { -1, 0 }
				else { app.log_quit('${@LOCATION} unknown orientation') }
			}
			if id == elem_crossing_bits { // same bits as wires so need to be separated
				// 1. done
				unsafe {
					chunkmap[x_map * chunk_size + y_map] = empty_id
				}
				// 2. done: no state & no struct

				// 3. done
				mut s_adj_id, mut s_is_input, _, mut s_y_off := app.wire_next_gate_id_coo(x,
					y, 0, 1)
				mut n_adj_id, mut n_is_input, _, mut n_y_off := app.wire_next_gate_id_coo(x,
					y, 0, -1)
				mut e_adj_id, mut e_is_input, mut e_x_off, _ := app.wire_next_gate_id_coo(x,
					y, 1, 0)
				mut w_adj_id, mut w_is_input, mut w_x_off, _ := app.wire_next_gate_id_coo(x,
					y, -1, 0)
				mut has_separated := false
				if s_adj_id != empty_id && n_adj_id != empty_id {
					if s_adj_id & elem_type_mask == elem_wire_bits
						&& n_adj_id & elem_type_mask == elem_wire_bits {
						// two wires or more: separate them
						mut adj_wires := [Coo{x, u32(y + n_y_off)},
							Coo{u32(x), u32(y + s_y_off)}]
						if s_adj_id & rid_mask == e_adj_id & rid_mask {
							adj_wires << Coo{u32(x + e_x_off), y}
						}
						if s_adj_id & rid_mask == w_adj_id & rid_mask {
							adj_wires << Coo{u32(x + w_x_off), y}
						}
						app.separate_wires(adj_wires, s_adj_id) // same id for north and south
						has_separated = true
					} else if s_adj_id & elem_type_mask == elem_wire_bits {
						// one side is a wire: add the new i/o for the wire & for the gate
						if n_is_input {
							app.remove_input(s_adj_id, n_adj_id)
							// not useful not a wire app.remove_output(n_adj_id, s_adj_id) // remove output of the gate
						} else {
							app.remove_output(s_adj_id, n_adj_id)
							app.remove_input(n_adj_id, s_adj_id) // remove output of the gate
						}
					} else if n_adj_id & elem_type_mask == elem_wire_bits {
						// one side is a wire: add the new i/o for the wire & for the gate
						if s_is_input {
							app.remove_input(n_adj_id, s_adj_id)
							// not useful app.remove_output(s_adj_id, n_adj_id) // remove output of the gate
						} else {
							app.remove_output(n_adj_id, s_adj_id)
							app.remove_input(s_adj_id, n_adj_id) // override output of the gate
						}
					} else {
						// If the two sides are standard gates:
						if s_is_input && !n_is_input { // s is the input of n
							app.remove_input(n_adj_id, id)
							app.remove_output(s_adj_id, id)
						} else if !s_is_input && n_is_input {
							app.remove_input(s_adj_id, id)
							app.remove_output(n_adj_id, id)
						}
					}
				}
				s_adj_id, s_is_input, _, s_y_off = app.wire_next_gate_id_coo(x, y, 0,
					1)
				n_adj_id, n_is_input, _, n_y_off = app.wire_next_gate_id_coo(x, y, 0,
					-1)
				e_adj_id, e_is_input, e_x_off, _ = app.wire_next_gate_id_coo(x, y, 1,
					0)
				w_adj_id, w_is_input, w_x_off, _ = app.wire_next_gate_id_coo(x, y, -1,
					0)
				if e_adj_id != empty_id && w_adj_id != empty_id {
					if e_adj_id & elem_type_mask == elem_wire_bits
						&& w_adj_id & elem_type_mask == elem_wire_bits {
						// two wires: separate them
						if e_adj_id & rid_mask == w_adj_id & rid_mask { // could already have been separated by north / south
							mut adj_wires := [Coo{u32(x + w_x_off), y},
								Coo{u32(x + e_x_off), y}]
							if e_adj_id & rid_mask == s_adj_id & rid_mask {
								adj_wires << Coo{u32(x), u32(y + s_y_off)}
							}
							if e_adj_id & rid_mask == n_adj_id & rid_mask {
								adj_wires << Coo{u32(x), u32(y + n_y_off)}
							}
							app.separate_wires(adj_wires, e_adj_id)
						}
					} else if e_adj_id & elem_type_mask == elem_wire_bits {
						// one side is a wire: add the new i/o for the wire & for the gate
						if w_is_input {
							if !has_separated { // If it has separated, it already removed the input while building back the wire
								app.remove_input(e_adj_id, w_adj_id)
								// not the wire -> not useful app.remove_output(w_adj_id, e_adj_id) // remove output of the gate
							}
						} else {
							if !has_separated {
								app.remove_output(e_adj_id, w_adj_id)
							}
							app.remove_input(w_adj_id, e_adj_id) // remove output of the gate
						}
					} else if w_adj_id & elem_type_mask == elem_wire_bits {
						// one side is a wire: add the new i/o for the wire & for the gate
						if e_is_input {
							// If it has separated, it already removed the input while building back the wire
							// because now on the map they are not linked
							if !has_separated {
								app.remove_input(w_adj_id, e_adj_id)
								// not the wire -> not useful app.remove_output(e_adj_id, w_adj_id) // remove output of the gate
							}
						} else {
							if !has_separated {
								app.remove_output(w_adj_id, e_adj_id)
							}
							app.remove_input(e_adj_id, w_adj_id) // remove output of the gate
						}
					} else {
						// If the two sides are standard gates:
						if e_is_input && !w_is_input { // s is the input of n
							app.remove_input(w_adj_id, id)
							app.remove_output(e_adj_id, id)
						} else if !e_is_input && w_is_input {
							app.remove_input(e_adj_id, id)
							app.remove_output(w_adj_id, id)
						}
					}
				}
				continue // do not get in the match
			}
			match id & elem_type_mask {
				elem_not_bits {
					// 1. done
					unsafe {
						chunkmap[x_map * chunk_size + y_map] = empty_id
					}
					// 2. done
					idx := id & rid_mask
					app.nots[idx].x = invalid_coo // now invalid
					app.add_dead_rid(.not, u64(idx))

					// 3. done
					inp_id := app.next_gate_id(x, y, -x_ori, -y_ori, id & ori_mask)
					out_id := app.next_gate_id(x, y, x_ori, y_ori, id & ori_mask)
					app.remove_input(out_id, id)
					app.remove_output(inp_id, id)
				}
				elem_diode_bits {
					// 1. done
					unsafe {
						chunkmap[x_map * chunk_size + y_map] = empty_id
					}
					// 2. done
					idx := id & rid_mask
					app.diodes[idx].x = invalid_coo
					app.add_dead_rid(.diode, u64(idx))

					// 3. done
					inp_id := app.next_gate_id(x, y, -x_ori, -y_ori, id & ori_mask)
					out_id := app.next_gate_id(x, y, x_ori, y_ori, id & ori_mask)
					app.remove_input(out_id, id)
					app.remove_output(inp_id, id)
				}
				elem_on_bits {
					// 1. done
					unsafe {
						chunkmap[x_map * chunk_size + y_map] = empty_id
					}
					// 2. done
					// no arrays for the ons

					// 3. done; only an input for other elements
					out_id := app.next_gate_id(x, y, x_ori, y_ori, id & ori_mask)
					app.remove_input(out_id, id)
				}
				elem_wire_bits {
					// Find if a part of an existing wire
					mut coo_adj_wire := []Coo{}
					mut adjacent_inps := []u64{}
					mut adjacent_outs := []u64{}
					for coo in cardinal_coords {
						adj_id, is_input, x_off, y_off := app.wire_next_gate_id_coo(x,
							y, coo[0], coo[1])
						assert adj_id != elem_crossing_bits
						if adj_id == empty_id {
						} else if adj_id & elem_type_mask == elem_wire_bits {
							coo_adj_wire << Coo{u32(int(x) + x_off), u32(int(y) + y_off)}
						} else {
							if is_input {
								adjacent_inps << adj_id // for the old inps
							} else {
								adjacent_outs << adj_id // for the old inps
							}
						}
					}

					// 1. done; doing it before the join because it would count it as a valid wire
					unsafe {
						chunkmap[x_map * chunk_size + y_map] = empty_id
					}
					// 2. done
					// Separate the wires:
					if coo_adj_wire.len > 1 {
						i := app.wires[id].cable_coords.index(Coo{x, y})
						app.wires[id].cable_coords.delete(i)
						app.wires[id].cable_chunk_i.delete(i)
						app.separate_wires(coo_adj_wire, id)
					} else if coo_adj_wire.len == 0 {
						idx := id & rid_mask
						app.wires[idx].cable_coords[0].x = invalid_coo
						app.add_dead_rid(.wire, u64(idx))
					} else { // if only 1 adjacent wire: remove the cable from the wire
						idx := id & rid_mask
						i := app.wires[idx].cable_coords.index(Coo{x, y})
						app.wires[idx].cable_coords.delete(i)
						app.wires[idx].cable_chunk_i.delete(i)
						for inp_id in adjacent_inps {
							i_ := app.wires[idx].inps.map(it & id_mask).index(inp_id & id_mask)
							app.wires[idx].inps.delete(i_)
						}
						for out_id in adjacent_outs {
							i_ := app.wires[idx].outs.map(it & id_mask).index(out_id & id_mask)
							app.wires[idx].outs.delete(i_)
						}
					}

					// 3. done
					for inp_id in adjacent_inps {
						app.remove_output(inp_id, id)
					}
					for out_id in adjacent_outs {
						app.remove_input(out_id, id)
					}
				}
				else {
					app.log_quit('${@LOCATION} should not get into this else')
				}
			}
		}
	}
}

// id: the id of the wire to separate (to reuse the old wire struct)
fn (mut app App) separate_wires(coo_adj_wires []Coo, id u64) {
	// for each cable on the cable (positions) stack
	// 	for each adjacent tile
	// 		if the tile is an i/o -> put in the i/o lists of the wire corresponding to the id of the cable
	//		if it is a cable (adj_cable)
	//			if adj_cable is already in a wire list:
	// 				if it is the same list as cable : already processed -> continue the for loop
	//				else :
	//				 merge the two wire lists: done
	// 					copy all the arrays of the first one into the second one
	//					replace all the ids of the second one by the first one's in the id_stack
	//					delete the second wire
	// 			else: add adj_cable to the wire list of cable
	//			add adj_cable in the stack (with it's wire id on the id_stack)
	//		else: do nothing
	if coo_adj_wires.len <= 0 {
		return
	}

	idx := id & rid_mask

	// TODO: Idea: do a similar thing for chunks? Possible problem: the virt_map would be too big/store too little info if sparse chunks

	// 1- iterate through the original wire cable list -> create an array (virt_map) of size max_x * max_y with info: is_wire & new_wires_id
	// 2- do the flood fill
	// 3- recreate the new wires from the virt_map + original wire cable list(chunk_i..) + flood fill inputs/outputs

	// Get the area of the wire
	mut min, mut max := app.wires[id].cable_coords[0], app.wires[id].cable_coords[0]
	for cc in app.wires[id].cable_coords {
		if cc.x > max.x {
			max.x = cc.x
		} else if cc.x < min.x {
			min.x = cc.x
		}
		if cc.y > max.y {
			max.y = cc.y
		} else if cc.y < min.y {
			min.y = cc.y
		}
	}
	c_area := Coo{max.x - min.x + 1, max.y - min.y + 1}

	// Init work area
	mut virt_map := []u8{len: int(c_area.x * c_area.y), init: -2} // -2: not wire, -1: not yet processed, >=0: new wire id
	for cc in app.wires[id].cable_coords {
		virt_cc := Coo{cc.x - min.x, cc.y - min.y}
		virt_map[virt_cc.x * c_area.y + virt_cc.y] = -1
	}
	mut inputs := [][]u64{len: coo_adj_wires.len}
	mut outputs := [][]u64{len: coo_adj_wires.len}
	for i, cc in coo_adj_wires {
		virt_cc := Coo{cc.x - min.x, cc.y - min.y}
		virt_map[virt_cc.x * c_area.y + virt_cc.y] = u8(i)
	}

	// Flood fill
	mut c_stack := []Coo{len: coo_adj_wires.len, cap: app.wires[idx].cable_coords.len}
	for i, cc in coo_adj_wires {
		c_stack[i] = cc
	}

	cable_stack: for c_stack.len > 0 { // for each wire in the stack
		cable := c_stack.pop()
		virt_cc := Coo{cable.x - min.x, cable.y - min.y}
		cable_id := virt_map[virt_cc.x * c_area.y + virt_cc.y]
		for coo in cardinal_coords { // for each adjacent tile
			mut adj_cc := Coo{u32(i64(cable.x) + coo[0]), u32(i64(cable.y) + coo[1])}
			mut v_adj_cc := Coo{u32(i64(virt_cc.x) + coo[0]), u32(i64(virt_cc.y) + coo[1])}
			if v_adj_cc.x == -1 || v_adj_cc.y == -1 || v_adj_cc.x >= c_area.x
				|| v_adj_cc.y >= c_area.y {
				// info: -1 is for u32(i64(0) - 1) that is > than 0. the coords should not get < -1
				// out of the virt_map -> check if is input/output and continue loop
				adj_id, is_input, _, _ := app.wire_next_gate_id_coo(cable.x, cable.y,
					coo[0], coo[1])
				if adj_id == empty_id {
					continue
				}
				// is NOT a cable -> else it would be in the same wire
				// add to the inputs/outputs
				if is_input {
					inputs[cable_id] << adj_id
				} else {
					outputs[cable_id] << adj_id
				}
				continue
			}
			mut map_idx := v_adj_cc.x * c_area.y + v_adj_cc.y
			mut map_val := virt_map[map_idx]
			if map_val == u8(-2) {
				// not wire -> check if here is a junction leading to a cable or an input/output
				adj_id, is_input, x_off, y_off := app.wire_next_gate_id_coo(cable.x, cable.y,
					coo[0], coo[1])
				if adj_id == empty_id {
					continue
				}
				if adj_id & elem_type_mask != elem_wire_bits { // if NOT a wire
					// add to the inputs/outputs
					if is_input {
						inputs[cable_id] << adj_id
					} else {
						outputs[cable_id] << adj_id
					}
					continue
				} else { // if is a wire
					// process it
					adj_cc = Coo{u32(i64(cable.x) + x_off), u32(i64(cable.y) + y_off)}
					v_adj_cc = Coo{adj_cc.x - min.x, adj_cc.y - min.y}
					map_idx = v_adj_cc.x * c_area.y + v_adj_cc.y
					map_val = virt_map[map_idx]
					// will be checked/processed by the next if
				}
			}
			if map_val == u8(-1) {
				// not processed wire -> process it
				virt_map[map_idx] = cable_id
				c_stack << adj_cc
			} else {
				if map_val != cable_id {
					// the two cables need to be merged
					for cc in app.wires[idx].cable_coords {
						v_cc := Coo{cc.x - min.x, cc.y - min.y}
						if virt_map[v_cc.x * c_area.y + v_cc.y] == map_val {
							virt_map[v_cc.x * c_area.y + v_cc.y] = cable_id
						}
					}
					// join the inputs and outputs
					inputs[cable_id] << inputs[map_val]
					outputs[cable_id] << outputs[map_val]
					inputs[map_val].clear()
					outputs[map_val].clear()
				}
			}
		}
	}

	// reconstruct the wires
	mut new_wires := []Wire{len: coo_adj_wires.len}
	for i, mut w in new_wires {
		w.inps << inputs[i]
		w.outs << outputs[i]
	}

	for i, cc in app.wires[idx].cable_coords {
		virt_cc := Coo{cc.x - min.x, cc.y - min.y}
		map_val := virt_map[virt_cc.x * c_area.y + virt_cc.y]
		new_wires[map_val].cable_coords << cc
		new_wires[map_val].cable_chunk_i << app.wires[idx].cable_chunk_i[i]
	}

	for i := new_wires.len - 1; i >= 0; i-- {
		if new_wires[i].cable_coords.len == 0 {
			new_wires.delete(i)
		}
	}

	// Create/Modify the new wires
	mut rids := []u64{len: new_wires.len}
	rids[0] = idx
	app.wires[idx] = new_wires[0]
	state0 := app.w_states[0][idx]
	state1 := app.w_states[1][idx]
	for i, mut wire in new_wires[1..] {
		mut dead_rid := app.get_free_dead_rid(.wire)
		rids[i + 1] = if dead_rid == 0 {
			u64(app.wires.len)
		} else {
			u64(dead_rid)
		}
		if dead_rid == 0 {
			app.wires << wire
		} else {
			app.wires[dead_rid] = wire
		}
		app.w_states[0] << state0
		app.w_states[1] << state1
	}

	// change the ids of the cables on the map and the I/O's i/o (actual I/O of the new wires)
	for j, wire in new_wires {
		for i, coo in wire.cable_coords {
			chunk_i := wire.cable_chunk_i[i]
			mut adj_chunkmap := &app.map[chunk_i].id_map
			adj_x_map := coo.x & chunk_bitmask
			adj_y_map := coo.y & chunk_bitmask
			unsafe {
				adj_chunkmap[adj_x_map * chunk_size + adj_y_map] &= on_bits // keep the state
				adj_chunkmap[adj_x_map * chunk_size + adj_y_map] |= rids[j] | elem_wire_bits // add the new id
			}
		}

		for inp in wire.inps {
			app.add_output(inp, rids[j] | elem_wire_bits)
		}
		for out in wire.outs {
			app.add_input(out, rids[j] | elem_wire_bits)
		}
	}
}

fn (mut app App) placement(_x_start u32, _y_start u32, _x_end u32, _y_end u32) {
	// 1.
	// set the tile id to:
	// the type (2 most significant bits)
	// the state (3rd) -> off by default
	// the orientation (4,5th)
	// the rid (all bits to the left)
	// 2.
	// add the struct to the array (with the right fields)
	// add the state to the arrays (there are 2 state arrays to fill /!\)
	// 3.
	// update the output/inputs fields of the adjacent elements

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
		// Output direction
		north { 0, -1 }
		south { 0, 1 }
		east { 1, 0 }
		west { -1, 0 }
		else { app.log_quit('${@LOCATION} unknown orientation') }
	}
	match app.selected_item {
		.not {
			mut chunk_i := app.get_chunkmap_idx_at_coords(x_start, y_start)
			mut last_cm_x := x_start
			mut last_cm_y := y_start
			for x in x_start .. x_end + 1 {
				for y in y_start .. y_end + 1 {
					if check_change_chunkmap(last_cm_x, last_cm_y, x, y) {
						last_cm_x = x
						last_cm_y = y
						chunk_i = app.get_chunkmap_idx_at_coords(x, y)
					}
					mut chunkmap := &app.map[chunk_i].id_map
					x_map := x & chunk_bitmask
					y_map := y & chunk_bitmask
					if unsafe { chunkmap[x_map * chunk_size + y_map] } != empty_id { // map not empty
						continue
					}

					// 1. done
					mut dead_rid := app.get_free_dead_rid(.not)
					rid := if dead_rid == 0 {
						i64(app.nots.len)
					} else {
						dead_rid
					}
					id := elem_not_bits | u64(rid) | app.selected_ori
					unsafe {
						chunkmap[x_map * chunk_size + y_map] = id
					}
					// 2. done
					inp_id := app.next_gate_id(x, y, -x_ori, -y_ori, id & ori_mask)
					if dead_rid == 0 {
						app.nots << Nots{i64(chunk_i), inp_id, x, y}
					} else {
						app.nots[rid] = Nots{i64(chunk_i), inp_id, x, y}
					}
					app.n_states[0] << false // default state & important to do the two lists
					app.n_states[1] << false // default state

					// 3. done
					out_id := app.next_gate_id(x, y, x_ori, y_ori, id & ori_mask)
					app.add_input(out_id, id)
					app.add_output(inp_id, id)
				}
			}
		}
		.diode {
			mut chunk_i := app.get_chunkmap_idx_at_coords(x_start, y_start)
			mut last_cm_x := x_start
			mut last_cm_y := y_start
			for x in x_start .. x_end + 1 {
				for y in y_start .. y_end + 1 {
					if check_change_chunkmap(last_cm_x, last_cm_y, x, y) {
						last_cm_x = x
						last_cm_y = y
						chunk_i = app.get_chunkmap_idx_at_coords(x, y)
					}
					mut chunkmap := &app.map[chunk_i].id_map
					x_map := x & chunk_bitmask
					y_map := y & chunk_bitmask
					if unsafe { chunkmap[x_map * chunk_size + y_map] } != empty_id { // map not empty
						continue
					}

					// 1. done
					mut dead_rid := app.get_free_dead_rid(.diode)
					rid := if dead_rid == 0 {
						i64(app.diodes.len)
					} else {
						dead_rid
					}
					id := elem_diode_bits | u64(rid) | app.selected_ori
					unsafe {
						chunkmap[x_map * chunk_size + y_map] = id
					}
					// 2. done
					inp_id := app.next_gate_id(x, y, -x_ori, -y_ori, id & ori_mask)
					if dead_rid == 0 {
						app.diodes << Diode{i64(chunk_i), inp_id, x, y}
					} else {
						app.diodes[dead_rid] = Diode{i64(chunk_i), inp_id, x, y}
					}
					app.d_states[0] << false // default state & important to do the two lists
					app.d_states[1] << false // default state

					// 3. done
					out_id := app.next_gate_id(x, y, x_ori, y_ori, id & ori_mask)
					app.add_input(out_id, id)
					app.add_output(inp_id, id)
				}
			}
		}
		.on {
			mut chunk_i := app.get_chunkmap_idx_at_coords(x_start, y_start)
			mut last_cm_x := x_start
			mut last_cm_y := y_start
			for x in x_start .. x_end + 1 {
				for y in y_start .. y_end + 1 {
					if check_change_chunkmap(last_cm_x, last_cm_y, x, y) {
						last_cm_x = x
						last_cm_y = y
						chunk_i = app.get_chunkmap_idx_at_coords(x, y)
					}
					mut chunkmap := &app.map[chunk_i].id_map
					x_map := x & chunk_bitmask
					y_map := y & chunk_bitmask
					if unsafe { chunkmap[x_map * chunk_size + y_map] } != empty_id { // map not empty
						continue
					}

					// 1. done
					id := elem_on_bits | on_bits | app.selected_ori
					unsafe {
						chunkmap[x_map * chunk_size + y_map] = id
					}
					// 2. done
					// no arrays for the ons

					// 3. done; only an input for other elements
					out_id := app.next_gate_id(x, y, x_ori, y_ori, id & ori_mask)
					app.add_input(out_id, id)
				}
			}
		}
		.wire {
			mut chunk_i := app.get_chunkmap_idx_at_coords(x_start, y_start)
			mut last_cm_x := x_start
			mut last_cm_y := y_start
			for x in x_start .. x_end + 1 {
				for y in y_start .. y_end + 1 {
					if check_change_chunkmap(last_cm_x, last_cm_y, x, y) {
						last_cm_x = x
						last_cm_y = y
						chunk_i = app.get_chunkmap_idx_at_coords(x, y)
					}
					mut chunkmap := &app.map[chunk_i].id_map
					x_map := x & chunk_bitmask
					y_map := y & chunk_bitmask
					if unsafe { chunkmap[x_map * chunk_size + y_map] } != empty_id { // map not empty
						continue
					}

					// Find if a part of an existing wire
					mut adjacent_wires := []u64{}
					mut adjacent_inps := []u64{}
					mut adjacent_outs := []u64{}
					for coo in cardinal_coords {
						adj_id, is_input, _, _ := app.wire_next_gate_id_coo(x, y, coo[0],
							coo[1])
						if adj_id == empty_id {
						} else if adj_id & elem_type_mask == elem_wire_bits {
							if app.wires[adj_id & rid_mask].cable_coords[0].x != invalid_coo {
								adjacent_wires << adj_id & id_mask
							}
						} else {
							if is_input {
								adjacent_inps << adj_id & id_mask // for the new inps
							} else {
								adjacent_outs << adj_id & id_mask // for the new inps
							}
						}
					}
					// remove redundancy:
					mut tmp_adj_wires := []u64{}
					for aw in adjacent_wires {
						if aw !in tmp_adj_wires {
							tmp_adj_wires << aw
						}
					}
					adjacent_wires = tmp_adj_wires.clone()
					// Join the wires:
					if adjacent_wires.len > 1 { // if only one wire, there is no need to join it
						app.join_wires(mut adjacent_wires)
					} else if adjacent_wires.len == 0 {
						mut dead_rid := app.get_free_dead_rid(.wire)
						rid := if dead_rid == 0 {
							i64(app.wires.len)
						} else {
							dead_rid
						}
						id := u64(rid) | elem_wire_bits
						adjacent_wires << id
						if dead_rid == 0 {
							app.wires << Wire{
								// rid: u64(rid)
							}
						} else {
							app.wires[dead_rid] = Wire{
								// rid: u64(rid)
							}
						}
						app.w_states[0] << false
						app.w_states[1] << false
					}
					first_i := adjacent_wires[0] & rid_mask

					// 1. done
					unsafe {
						if app.w_states[app.actual_state][first_i] {
							chunkmap[x_map * chunk_size + y_map] = elem_wire_bits | adjacent_wires[0] | on_bits
						} else {
							chunkmap[x_map * chunk_size + y_map] = elem_wire_bits | adjacent_wires[0]
						}
					} // no orientation

					// 2. done
					app.wires[first_i].cable_coords << Coo{x, y}
					app.wires[first_i].cable_chunk_i << chunk_i
					app.wires[first_i].inps << adjacent_inps
					app.wires[first_i].outs << adjacent_outs

					// 3. done
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
			mut chunk_i := app.get_chunkmap_idx_at_coords(x_start, y_start)
			mut last_cm_x := x_start
			mut last_cm_y := y_start
			for x in x_start .. x_end + 1 {
				for y in y_start .. y_end + 1 {
					if check_change_chunkmap(last_cm_x, last_cm_y, x, y) {
						last_cm_x = x
						last_cm_y = y
						chunk_i = app.get_chunkmap_idx_at_coords(x, y)
					}
					mut chunkmap := &app.map[chunk_i].id_map
					x_map := x & chunk_bitmask
					y_map := y & chunk_bitmask
					if unsafe { chunkmap[x_map * chunk_size + y_map] } != empty_id { // map not empty
						continue
					}
					// 1. done; they all have the same id
					unsafe {
						chunkmap[x_map * chunk_size + y_map] = elem_crossing_bits
					}
					// 2. done: no state & no struct

					// 3. done
					s_adj_id, s_is_input, _, _ := app.wire_next_gate_id_coo(x, y, 0, 1)
					n_adj_id, n_is_input, _, _ := app.wire_next_gate_id_coo(x, y, 0, -1)
					if s_adj_id != empty_id && n_adj_id != empty_id {
						if s_adj_id & elem_type_mask == elem_wire_bits
							&& n_adj_id & elem_type_mask == elem_wire_bits {
							// two wires: join them
							mut adjacent_wires := [s_adj_id, n_adj_id]
							// remove redundancy:
							mut tmp_adj_wires := []u64{}
							for aw in adjacent_wires {
								if aw !in tmp_adj_wires {
									tmp_adj_wires << aw
								}
							}
							adjacent_wires = tmp_adj_wires.clone()
							app.join_wires(mut adjacent_wires)
						} else if s_adj_id & elem_type_mask == elem_wire_bits {
							// one side is a wire: add the new i/o for the wire & for the gate
							if n_is_input {
								app.add_input(s_adj_id, n_adj_id) // add an input to the wire
								app.add_output(n_adj_id, s_adj_id) // add an output to the gate
							} else {
								app.add_input(n_adj_id, s_adj_id)
								app.add_output(s_adj_id, n_adj_id)
							}
						} else if n_adj_id & elem_type_mask == elem_wire_bits {
							// one side is a wire: add the new i/o for the wire & for the gate
							if s_is_input {
								app.add_input(n_adj_id, s_adj_id)
								app.add_output(s_adj_id, n_adj_id)
							} else {
								app.add_input(s_adj_id, n_adj_id)
								app.add_output(n_adj_id, s_adj_id)
							}
						} else {
							// gates on the two sides
							if s_is_input && !n_is_input { // s is the input of n
								app.add_input(n_adj_id, s_adj_id)
								app.add_output(s_adj_id, n_adj_id)
							} else if !s_is_input && n_is_input {
								app.add_input(s_adj_id, n_adj_id)
								app.add_output(n_adj_id, s_adj_id)
							}
						}
					}
					e_adj_id, e_is_input, _, _ := app.wire_next_gate_id_coo(x, y, 1, 0)
					w_adj_id, w_is_input, _, _ := app.wire_next_gate_id_coo(x, y, -1,
						0)
					if e_adj_id != empty_id && w_adj_id != empty_id {
						if e_adj_id & elem_type_mask == elem_wire_bits
							&& w_adj_id & elem_type_mask == elem_wire_bits {
							// two wires: join them
							mut adjacent_wires := [e_adj_id, w_adj_id]
							// remove redundancy:
							mut tmp_adj_wires := []u64{}
							for aw in adjacent_wires {
								if aw !in tmp_adj_wires {
									tmp_adj_wires << aw
								}
							}
							adjacent_wires = tmp_adj_wires.clone()
							app.join_wires(mut adjacent_wires)
						} else if e_adj_id & elem_type_mask == elem_wire_bits {
							// one side is a wire: add the new i/o for the wire & for the gate
							if w_is_input {
								app.add_input(e_adj_id, w_adj_id) // add an input to the wire
								app.add_output(w_adj_id, e_adj_id) // add an output to the gate
							} else {
								app.add_input(w_adj_id, e_adj_id)
								app.add_output(e_adj_id, w_adj_id)
							}
						} else if w_adj_id & elem_type_mask == elem_wire_bits {
							// one side is a wire: add the new i/o for the wire & for the gate
							if e_is_input {
								app.add_input(w_adj_id, e_adj_id) // add an input to the wire
								app.add_output(e_adj_id, w_adj_id) // add an output to the gate
							} else {
								app.add_input(e_adj_id, w_adj_id)
								app.add_output(w_adj_id, e_adj_id)
							}
						} else {
							// gates on the two sides
							if e_is_input && !w_is_input { // s is the input of n
								app.add_input(w_adj_id, e_adj_id)
								app.add_output(e_adj_id, w_adj_id)
							} else if !e_is_input && w_is_input {
								app.add_input(e_adj_id, w_adj_id)
								app.add_output(w_adj_id, e_adj_id)
							}
						}
					}

					// 4. done: no rid
				}
			}
		}
	}
}

fn (mut app App) join_wires(mut adjacent_wires []u64) {
	//	adjacent_wires.sort() // the id order is the same as the idx order so no problem for deletion
	first_i := adjacent_wires[0] & rid_mask
	for wire in adjacent_wires[1..] { // find the state
		i := wire & rid_mask
		app.w_states[app.actual_state][first_i] = app.w_states[app.actual_state][first_i]
			|| app.w_states[app.actual_state][i]
	}
	state := app.w_states[app.actual_state][first_i]
	if state { // update the first wire's state
		for i, coo in app.wires[first_i].cable_coords {
			// change the id of all the cables on the map
			chunk_i := app.wires[first_i].cable_chunk_i[i]
			mut w_chunkmap := &app.map[chunk_i].id_map
			unsafe {
				w_chunkmap[(coo.x & chunk_bitmask) * chunk_size + coo.y & chunk_bitmask] |= on_bits
			}
		}
	}
	// join the other wires with the first one
	for wire in adjacent_wires[1..] {
		i := wire & rid_mask
		for c_i, coo in app.wires[i].cable_coords {
			// change the id of all the cables on the map
			chunk_i := app.wires[i].cable_chunk_i[c_i]
			mut w_chunkmap := &app.map[chunk_i].id_map
			unsafe {
				if state {
					w_chunkmap[(coo.x & chunk_bitmask) * chunk_size + coo.y & chunk_bitmask] = adjacent_wires[0] | on_bits
				} else {
					w_chunkmap[(coo.x & chunk_bitmask) * chunk_size + coo.y & chunk_bitmask] = adjacent_wires[0]
				}
			}
		}
		// change the inputs / outputs' i/o ids
		for inp in app.wires[i].inps {
			app.add_output(inp, adjacent_wires[0])
		}
		for out in app.wires[i].outs {
			app.add_input(out, adjacent_wires[0])
		}
		// merge all the arrays in the new main wire
		app.wires[first_i].cable_coords << app.wires[i].cable_coords
		app.wires[first_i].cable_chunk_i << app.wires[i].cable_chunk_i
		app.wires[first_i].inps << app.wires[i].inps
		app.wires[first_i].outs << app.wires[i].outs
		// delete the old wires, the map does not need update as the same cables are now in the new one
		app.wires[i].cable_coords[0].x = invalid_coo
	}
}

// get the input of the elem (empty_id for wires & ons)
fn (mut app App) get_input(elem_id u64) u64 {
	if elem_id != empty_id && elem_id != elem_crossing_bits {
		if elem_id & elem_type_mask == elem_not_bits { // not
			if app.nots[elem_id & rid_mask].x != invalid_coo {
				idx := elem_id & rid_mask
				return app.nots[idx].inp
			}
		} else if elem_id & elem_type_mask == elem_diode_bits { // diode
			if app.diodes[elem_id & rid_mask].x != invalid_coo {
				idx := elem_id & rid_mask
				return app.diodes[idx].inp
			}
		} else if elem_id & elem_type_mask == elem_on_bits { // on -> does not have inputs
		} else if elem_id & elem_type_mask == elem_wire_bits { // wire
		}
	}
	return empty_id
}

// add input_id to the input(s) of elem_id (if it is a valid id)
fn (mut app App) add_input(elem_id u64, input_id u64) {
	if elem_id != empty_id && elem_id != elem_crossing_bits {
		idx := elem_id & rid_mask
		if elem_id & elem_type_mask == elem_not_bits { // not
			app.nots[idx].inp = input_id
		} else if elem_id & elem_type_mask == elem_diode_bits { // diode
			app.diodes[idx].inp = input_id
		} else if elem_id & elem_type_mask == elem_on_bits { // on -> does not have inputs
		} else if elem_id & elem_type_mask == elem_wire_bits { // wire
			app.wires[idx].inps << input_id
		}
	}
}

fn (mut app App) remove_input(elem_id u64, input_id u64) {
	if elem_id != empty_id && elem_id != elem_crossing_bits {
		idx := elem_id & rid_mask
		if elem_id & elem_type_mask == elem_not_bits { // not
			app.nots[idx].inp = empty_id
		} else if elem_id & elem_type_mask == elem_diode_bits { // diode
			app.diodes[idx].inp = empty_id
		} else if elem_id & elem_type_mask == elem_on_bits { // on -> does not have inputs
		} else if elem_id & elem_type_mask == elem_wire_bits { // wire
			i := app.wires[idx].inps.map(it & id_mask).index(input_id & id_mask)
			app.wires[idx].inps.delete(i)
		}
	}
}

// add output_id to the output(s) of elem_id (if it is a valid id)
fn (mut app App) add_output(elem_id u64, output_id u64) {
	if elem_id != empty_id && elem_id != elem_crossing_bits {
		if elem_id & elem_type_mask == elem_wire_bits { // wire
			idx := elem_id & rid_mask
			app.wires[idx].outs << output_id
		}
	}
}

fn (mut app App) remove_output(elem_id u64, output_id u64) {
	if elem_id != empty_id && elem_id != elem_crossing_bits {
		if elem_id & elem_type_mask == elem_wire_bits { // wire
			idx := elem_id & rid_mask
			i := app.wires[idx].outs.map(it & id_mask).index(output_id & id_mask)
			app.wires[idx].outs.delete(i)
		}
	}
}

// Returns - the id of the next gate that is not orthogonal with these coordinates on the x/y_dir specified
//         - whether or not the next gate is an input or an output of the wire
// Returns empty_id if not a valid input/output
// x_dir -> direction of the step
// the selected ori is irrelevant and will need to use the step direction instead
// returns id, (next_gate is input of the gate), x_delta, y_delta
// example: id, false, 21, 23 -> is an output
fn (mut app App) wire_next_gate_id_coo(x u32, y u32, x_dir int, y_dir int) (u64, bool, i64, i64) {
	conv_x := u32(int(x) + x_dir)
	conv_y := u32(int(y) + y_dir)
	mut chunk_i := app.get_chunkmap_idx_at_coords(conv_x, conv_y)
	mut last_cm_x := conv_x
	mut last_cm_y := conv_y
	mut next_chunkmap := &app.map[chunk_i].id_map
	mut next_id := unsafe {
		next_chunkmap[(conv_x & chunk_bitmask) * chunk_size + conv_y & chunk_bitmask]
	}
	mut input := false
	// Check if next gate's orientation is matching and not orthogonal
	if next_id == elem_crossing_bits {
		// check until other than crossing
		mut x_off := i64(x_dir)
		mut y_off := i64(y_dir)
		for next_id == elem_crossing_bits {
			x_off += x_dir
			y_off += y_dir
			x_conv := u32(i64(x) + x_off)
			y_conv := u32(i64(y) + y_off)
			if x_conv & chunk_inv_bitmask != last_cm_x & chunk_inv_bitmask
				|| y_conv & chunk_inv_bitmask != last_cm_y & chunk_inv_bitmask { // inlined check_change_chunkmap
				last_cm_x = x_conv
				last_cm_y = y_conv
				chunk_i = app.get_chunkmap_idx_at_coords(x_conv, y_conv)
				next_chunkmap = &app.map[chunk_i].id_map
			}
			next_id = unsafe {
				next_chunkmap[(x_conv & chunk_bitmask) * chunk_size + y_conv & chunk_bitmask]
			}
		}
		next_id2, input2, _, _ := app.wire_next_gate_id_coo(u32(int(x) + x_off - x_dir),
			u32(int(y) + y_off - y_dir), x_dir, y_dir) // coords of the crossing just before the detected good elem
		return next_id2, input2, x_off, y_off
	} else if next_id == empty_id {
		next_id = empty_id
	} else if next_id & elem_type_mask == elem_on_bits {
		// need to return the id of the on gates (all the ons have the same) not an empty one if it is an input -> to know it is always ON
		opp_step_ori := match [x_dir, y_dir]! {
			[0, 1]! {
				north
			}
			[0, -1]! {
				south
			}
			[1, 0]! {
				west
			}
			[-1, 0]! {
				east
			}
			else {
				app.log_quit('${@LOCATION} not a valid step for an orientation')
			}
		}
		if opp_step_ori != next_id & ori_mask { // is not an input of the gate
			next_id = empty_id
		} else {
			input = true
		}
	} else if next_id & elem_type_mask == elem_wire_bits {
		if app.wires[next_id & rid_mask].cable_coords[0].x == invalid_coo {
			next_id = empty_id
		}
	} else if next_id & elem_type_mask == elem_not_bits {
		// Need to find the ori of the step and do the check
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
			input = false // output
		} else if next_id & ori_mask == opposite_ori {
			input = true
		} else {
			next_id = empty_id
		}
		// if app.nots[next_id & rid_mask].x == invalid_coo { Next id should be empty_id in this case
		//	next_id = empty_id
		//}
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
			input = false // output
		} else if next_id & ori_mask == opposite_ori {
			input = true
		} else {
			next_id = empty_id
		}
		// if app.diodes[next_id & rid_mask].x == invalid_coo {
		//	next_id = empty_id
		//}
	}
	return next_id, input, x_dir, y_dir
}

// Returns the id of the next gate that is connected to the gate (on x, y) walking on the x_dir/y_dir specified
// Returns empty_id if not a valid input/output
// x_dir -> direction of the step
// gate_ori : the orientation of the gate used as starting point
fn (mut app App) next_gate_id(x u32, y u32, x_dir int, y_dir int, gate_ori u64) u64 {
	conv_x := u32(int(x) + x_dir)
	conv_y := u32(int(y) + y_dir)
	mut chunk_i := app.get_chunkmap_idx_at_coords(conv_x, conv_y)
	mut last_cm_x := conv_x
	mut last_cm_y := conv_y
	mut next_chunkmap := &app.map[chunk_i].id_map
	mut next_id := unsafe {
		next_chunkmap[(conv_x & chunk_bitmask) * chunk_size + conv_y & chunk_bitmask]
	}
	// Check if next gate's orientation is matching and not orthogonal
	if next_id == elem_crossing_bits {
		// check until wire
		mut x_off := i64(x_dir)
		mut y_off := i64(y_dir)
		for next_id == elem_crossing_bits {
			x_off += x_dir
			y_off += y_dir
			x_conv := u32(i64(x) + x_off)
			y_conv := u32(i64(y) + y_off)
			if check_change_chunkmap(last_cm_x, last_cm_y, x_conv, y_conv) {
				last_cm_x = x_conv
				last_cm_y = y_conv
				chunk_i = app.get_chunkmap_idx_at_coords(x_conv, y_conv)
			}
			next_chunkmap = &app.map[chunk_i].id_map
			next_id = unsafe {
				next_chunkmap[(x_conv & chunk_bitmask) * chunk_size + y_conv & chunk_bitmask]
			}
		}
		return app.next_gate_id(u32(int(x) + x_off - x_dir), u32(int(y) + y_off - y_dir),
			x_dir, y_dir, gate_ori) // coords of the crossing just before the detected good elem
	} else if next_id == empty_id {
		next_id = empty_id
	} else if next_id & elem_type_mask == elem_on_bits {
		// need to return the id of the on gates (all the ons have the same) not an empty one if it is an input -> to know it is always ON
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
		if step_ori == gate_ori || next_id & ori_mask != gate_ori { // is an output of the gate or is not aligned (because the next is a ON)
			next_id = empty_id
		}
	} else if next_id & elem_type_mask == elem_wire_bits {
		if app.wires[next_id & rid_mask].cable_coords[0].x == invalid_coo {
			next_id = empty_id
		}
	} else if next_id & elem_type_mask == elem_not_bits {
		if next_id & ori_mask != gate_ori {
			next_id = empty_id
		}
		if app.nots[next_id & rid_mask].x == invalid_coo {
			next_id = empty_id
		}
	} else if next_id & elem_type_mask == elem_diode_bits {
		if next_id & ori_mask != gate_ori {
			next_id = empty_id
		}
		if app.diodes[next_id & rid_mask].x == invalid_coo {
			next_id = empty_id
		}
	}
	return next_id
}

fn (mut app App) set_elem_state_by_pos(x u32, y u32) {
	mut chunk_i := app.get_chunkmap_idx_at_coords(x, y)
	mut chunkmap := &app.map[chunk_i].id_map
	mut xmap := x & chunk_bitmask
	mut ymap := y & chunk_bitmask
	mut id := unsafe { chunkmap[xmap * chunk_size + ymap] }
	if id == elem_crossing_bits || id == empty_id || id & elem_type_mask == elem_on_bits {
		return
	}
	i := unsafe { chunkmap[xmap * chunk_size + ymap] } & rid_mask
	if id & elem_type_mask == elem_wire_bits {
		unsafe {
			chunkmap[xmap * chunk_size + ymap] = chunkmap[xmap * chunk_size + ymap] | on_bits
		}
		app.w_states[app.actual_state][i] = true
		mut last_cm_x := x
		mut last_cm_y := y
		for cc in app.wires[i].cable_coords {
			if check_change_chunkmap(last_cm_x, last_cm_y, cc.x, cc.y) {
				last_cm_x = cc.x
				last_cm_y = cc.y
				chunk_i = app.get_chunkmap_idx_at_coords(cc.x, cc.y)
			}
			chunkmap = &app.map[chunk_i].id_map
			xmap = cc.x & chunk_bitmask
			ymap = cc.y & chunk_bitmask
			id = unsafe { chunkmap[xmap * chunk_size + ymap] }
			unsafe {
				chunkmap[xmap * chunk_size + ymap] = chunkmap[xmap * chunk_size + ymap] | on_bits
			}
		}
	} else if id & elem_type_mask == elem_not_bits {
		unsafe {
			chunkmap[xmap * chunk_size + ymap] = chunkmap[xmap * chunk_size + ymap] & (~on_bits)
		}
		app.n_states[app.actual_state][i] = false
	} else if id & elem_type_mask == elem_diode_bits {
		unsafe {
			chunkmap[xmap * chunk_size + ymap] = chunkmap[xmap * chunk_size + ymap] | on_bits
		}
		app.d_states[app.actual_state][i] = true
	}
}

// A tick is a unit of time. For each tick, a complete update cycle/process will be effected.
// Update process:
// 1. change which states lists are the actual ones (/!\ when creating/destroying an element, the program must update the actual and the old state lists)
// 2. for each element in the element lists (nots, diodes, wires) do steps 3 and 4
// 3. look at the previous state(s) of the input(s) in the old states lists
// 4. update it's state (in the actual state list and in the id stored in the chunks) accordingly
// It is updated like a graph to avoid running into update order issues.
fn (mut app App) update_cycle() {
	// 1. done
	app.actual_state = (app.actual_state + 1) % 2
	// 2. done
	for i, not in app.nots {
		if not.x != invalid_coo {
			// 3. done
			old_inp_state := app.get_elem_state_by_id(not.inp, 1)
			// 4. done
			app.n_states[app.actual_state][i] = !old_inp_state
			mut chunkmap := &app.map[not.chunk_i].id_map
			xmap := not.x & chunk_bitmask
			ymap := not.y & chunk_bitmask
			if old_inp_state {
				unsafe {
					chunkmap[xmap * chunk_size + ymap] = chunkmap[xmap * chunk_size + ymap] & (~on_bits)
				}
			} else {
				unsafe {
					chunkmap[xmap * chunk_size + ymap] = chunkmap[xmap * chunk_size + ymap] | on_bits
				}
			}
		}
	}
	for i, diode in app.diodes {
		if diode.x != invalid_coo {
			// 3. done
			old_inp_state := app.get_elem_state_by_id(diode.inp, 1)
			// 4. done
			app.d_states[app.actual_state][i] = old_inp_state
			mut chunkmap := &app.map[diode.chunk_i].id_map
			xmap := diode.x & chunk_bitmask
			ymap := diode.y & chunk_bitmask
			if old_inp_state {
				unsafe {
					chunkmap[xmap * chunk_size + ymap] = chunkmap[xmap * chunk_size + ymap] | on_bits
				}
			} else {
				unsafe {
					chunkmap[xmap * chunk_size + ymap] = chunkmap[xmap * chunk_size + ymap] & (~on_bits)
				}
			}
		}
	}
	for i, wire in app.wires {
		if wire.cable_coords[0].x != invalid_coo {
			// 3. done
			mut old_or_inp_state := false // will be all the inputs of the wire ORed
			for inp in wire.inps {
				old_inp_state := app.get_elem_state_by_id(inp, 1)
				if old_inp_state {
					old_or_inp_state = true // only one is needed for the OR to be true
					break
				}
			}
			// 4. done
			app.w_states[app.actual_state][i] = old_or_inp_state
			for c_i, cable_coo in wire.cable_coords {
				chunk_i := wire.cable_chunk_i[c_i]
				mut chunkmap := &app.map[chunk_i].id_map
				xmap := cable_coo.x & chunk_bitmask
				ymap := cable_coo.y & chunk_bitmask
				if old_or_inp_state {
					unsafe {
						chunkmap[xmap * chunk_size + ymap] = chunkmap[xmap * chunk_size + ymap] | on_bits
					}
				} else {
					unsafe {
						chunkmap[xmap * chunk_size + ymap] = chunkmap[xmap * chunk_size + ymap] & (~on_bits)
					}
				}
			}
		}
	}
}

@[inline]
fn check_change_chunkmap(x u32, y u32, x1 u32, y1 u32) bool {
	return x & chunk_inv_bitmask != x1 & chunk_inv_bitmask
		|| y & chunk_inv_bitmask != y1 & chunk_inv_bitmask
}

fn (mut app App) get_chunkmap_idx_at_coords(x u32, y u32) int {
	x_ := x & chunk_inv_bitmask
	y_ := y & chunk_inv_bitmask
	coo := (u64(x_) << 32) | u64(y_)
	return app.chunk_cache[coo] or {
		for i, chunk in app.map {
			if x_ == chunk.x && y == chunk.y {
				app.chunk_cache[coo] = i
				i
			}
		}
		// chunk not found, create it
		app.map << Chunk{
			x:      x_
			y:      y_
			id_map: []u64{len: chunk_size * chunk_size}
		}
		last_i := app.map.len - 1
		unsafe { app.map[last_i].id_map.flags.set(.nogrow | .noshrink) }
		app.chunk_cache[coo] = app.map.len - 1
		app.map.len - 1
	}
}

// previous: 0 for actual state, 1 for the previous state
// returns the state of the concerned element & the index in the list
// crossing & ons dont have different states nor idx
fn (mut app App) get_elem_state_by_id(id u64, previous int) bool {
	concerned_state := (app.actual_state + previous) % 2
	rid := id & rid_mask
	// the state in the id may be an old state so it needs to get the state from the state lists
	if id == empty_id {
		return false
	}
	if id & elem_type_mask == elem_on_bits { // on
		return true
	} else if id & elem_type_mask == elem_not_bits { // not
		return app.n_states[concerned_state][rid]
	} else if id & elem_type_mask == elem_diode_bits { // diode
		return app.d_states[concerned_state][rid]
	} else if id & elem_type_mask == elem_wire_bits { // wire
		return app.w_states[concerned_state][rid]
	}
	app.log_quit('${@LOCATION} id not found in get_elem_state_by_id: ${id & rid_mask}')
}

// TODO: Explain ids
// RIDs are pure rids (the index in the array of it's type)
// pure id: rid | elem_type_bits
// others ids like inp out, are unpure ids by default (assume they are) -> if you want it's id without state/orientation -> & id_mask, if you want it's rid -> & rid_mask

// An element is a something placed on the map (so not empty)
// A gate is an element with some inputs or some outputs or both
// The orientation of a gate is where the output is facing

// Crossing: a special element that links it's north & south sides and (separately) it's west and east sides as if it was not there
// Example: a not gate facing west placed next to a crossing (the not gate is on it's west side), will have as input the element placed next to the crossing on the east side

struct Chunk {
mut:
	id_map []u64 // [x][y] x++=east y++=south, of total size chunk_size * chunk_size
	x      u32
	y      u32
}

// A gate that outputs the opposite of the input signal
struct Nots {
mut:
	chunk_i i64
	inp     u64 // id of the input element of the not gate
	// Map coordinates
	x u32
	y u32
}

// A gate that transmit the input signal to the output element (unidirectionnal) and adds 1 tick delay (1 update cycle to update)
struct Diode {
mut:
	chunk_i i64
	inp     u64 // id of the input element of the not gate
	// Map coordinates
	x u32
	y u32
}

// ON: a gate that is always ON (only on one side)

// Cables are the individually placable element and two cables are connected if one of
// them is already connected to one that is connected to the other or the two cables are next to each other
// If some cables are connected, they shared their states by being a wire

// a Wire is made out of multiple cables that are connected
// It outputs the OR of all it's inputs
struct Wire {
mut:
	inps          []u64 // id of the input elements outputing to the wire
	outs          []u64 // id of the output elements whose inputs are the wire
	cable_coords  []Coo // all the x y coordinates of the individual cables (elements) the wire is made of
	cable_chunk_i []i64 // chunk index for each cable
}

struct Coo {
mut:
	x u32
	y u32
}
