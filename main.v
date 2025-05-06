module main

// TODO: add tests for the backend
import math { pow }
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
const chunk_size = 100
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
	steal_settings    // edit
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

struct ColorChip { // TODO: save color chips and keyboard inputs too
	x u32
	y u32
	w u32
	h u32
mut:
	colors []gg.Color // colors to show
	inputs [][2]u32   // the state will be converted to a number (binary) and it will be the index of the shown color
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
	.steal_settings:       ButtonData{
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
	.quit_map:             ButtonData{
		pos: 15
	}
	.selection_delete:     ButtonData{
		pos: 7
	}
}

struct App {
mut:
	ctx               &gg.Context = unsafe { nil }
	e                 &gg.Event   = &gg.Event{}
	draw_count        int         = 1
	draw_step         int         = 1000 // number of draw calls before .end( passthru
	tile_size         int         = 50
	text_input        string // holds what the user typed
	colorchips_hidden bool   // if colorchips are hidden
	mouse_down        bool
	mouse_map_x       u32
	mouse_map_y       u32
	scroll_pos        f32
	// main menu
	main_menu        bool
	button_solo_x    f32 = 0.0 // TODO: make it scale with screensize and place it properly
	button_solo_y    f32 = 0.0
	button_solo_w    f32 = 300.0
	button_solo_h    f32 = 300.0
	button_quit_size f32 = 50.0
	btn_quit_ofst    f32 = 20.0
	solo_img         gg.Image
	// solo menu TODO: display map info of the hovered map (size bits, nb of hours played, gates placed... fun stuff)
	solo_menu           bool
	map_names_list      []string // without folder name
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
	// edit mode -> edit colorchips
	edit_mode                 bool
	editmenu_rgb_y            f32 = 10.0
	editmenu_rgb_h            f32 = 40.0
	editmenu_rgb_w            f32 = 40.0
	editmenu_r_x              f32 = 60.0
	editmenu_g_x              f32 = 110.0
	editmenu_b_x              f32 = 160.0
	editmenu_offset_x         f32 = 160.0 // TODO: scale w/ screen size
	editmenu_offset_y         f32 = 160.0 // TODO: scale
	editmenu_nb_color_by_row  int = 10
	editmenu_colorsize        f32 = 50.0
	editmenu_selected_color   int // TODO: show coords of input
	editmenu_offset_inputs_x  f32 = 160.0 // TODO: scale w/ screen size
	editmenu_offset_inputs_y  f32 = 160.0 // TODO: scale
	editmenu_nb_inputs_by_row int = 10
	editmenu_inputsize        f32 = 50.0
	delete_colorchip_submode  bool
	create_colorchip_submode  bool // select start and end of the new colorchip
	create_colorchip_x        u32 = u32(-1)
	create_colorchip_y        u32 = u32(-1)
	create_colorchip_endx     u32 = u32(-1)
	create_colorchip_endy     u32 = u32(-1)
	choose_colorchip_submode  bool // select a colorchip to edit
	steal_settings_submode    bool
	add_input_submode         bool // to add an input to a colorchip
	edit_color_submode        bool // edit colors of a colorchip
	selected_colorchip        int  // index of the selected colorchip
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
	load_gate_mode   bool
	gate_name_list   []string // without folder name
	gate_x_ofst      f32 = 5.0
	gate_y_offset    f32 = 50.0
	gate_top_spacing f32 = 10.0
	gate_h           f32 = 50.0
	gate_w           f32 = 500.0
	// save gate mode
	save_gate_mode bool
	// keyboard input (force state of a gate to ON) mode
	keyinput_mode bool
	key_pos       map[u8][][2]u32 // `n` -> [[0, 3], [32, 53]] : will force the state to ON at x:0 y:3 and x:32 y:53
	tmp_pos_x     u32 = u32(-1)
	tmp_pos_y     u32 = u32(-1)
	// UI on the left border, TODO: need to make it scaling automatically w/ screensize
	ui_width            f32                    = 50.0
	button_size         f32                    = 40.0
	button_left_padding f32                    = 5.0
	button_top_padding  f32                    = 5.0
	buttons             map[Buttons]ButtonData = button_map.clone()
	log                 string
	log_timer           int

	// logic
	map             []Chunk
	map_name        string // to fill when loading a map
	comp_running    bool   // is a map loaded and running
	pause           bool   // is the map updating
	nb_updates      int = 5 // number of updates per second
	avg_update_time f64 // nanosecs
	todo            []TodoInfo
	selected_item   Elem
	selected_ori    u64 = north
	copied          []PlaceInstruction
	actual_state    int // indicate which list is the old state list and which is the actual one, 0 for the first, 1 for the second
	nots            []Nots
	n_next_rid      u64 = 1
	n_states        [2][]bool // the old state and the actual state list
	diodes          []Diode
	d_next_rid      u64 = 1
	d_states        [2][]bool
	wires           []Wire
	w_next_rid      u64 = 1
	w_states        [2][]bool
	forced_states   [][2]u32    // forced to ON state by a keyboard input
	colorchips      []ColorChip // screens
	palette         Palette = palette_def // TODO: edit palette and save palette
	comp_alive      bool
	chunk_cache     map[u64]int // x u32 y u32 -> index of app.map
}

// graphics

fn main() {
	mut app := &App{}
	app.ctx = gg.new_context(
		create_window: true
		window_title:  'Nots'
		user_data:     app
		frame_fn:      on_frame
		event_fn:      on_event
		sample_count:  4
		bg_color:      app.palette.background
		font_path:     font_path
	)
	app.log('Start: ${time.now()}')
	// lancement du programme/de la fenêtre
	app.main_menu = true
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
		app.buttons[.item_nots].img = app.ctx.create_image(sprites_path + 'item_nots.png')!
		app.buttons[.create_color_chip].img = app.ctx.create_image(sprites_path +
			'create_color_chip.png')!
		app.buttons[.add_input].img = app.ctx.create_image(sprites_path + 'add_input.png')!
		app.buttons[.item_diode].img = app.ctx.create_image(sprites_path + 'item_diode.png')!
		app.buttons[.steal_settings].img = app.ctx.create_image(sprites_path + 'steal_settings.png')!
		app.buttons[.item_crossing].img = app.ctx.create_image(sprites_path + 'item_crossing.png')!
		app.buttons[.delete_colorchip].img = app.ctx.create_image(sprites_path +
			'delete_colorchip.png')!
		app.buttons[.item_on].img = app.ctx.create_image(sprites_path + 'item_on.png')!
		app.buttons[.item_wire].img = app.ctx.create_image(sprites_path + 'item_wire.png')!
		app.buttons[.speed].img = app.ctx.create_image(sprites_path + 'speed.png')!
		app.buttons[.slow].img = app.ctx.create_image(sprites_path + 'slow.png')!
		app.buttons[.pause].img = app.ctx.create_image(sprites_path + 'pause.png')!
		app.buttons[.paste].img = app.ctx.create_image(sprites_path + 'paste.png')!
		app.buttons[.save_map].img = app.ctx.create_image(sprites_path + 'save_map.png')!
		app.buttons[.keyinput].img = app.ctx.create_image(sprites_path + 'keyinput.png')!
		app.buttons[.hide_colorchips].img = app.ctx.create_image(sprites_path +
			'hide_colorchips.png')!
		app.buttons[.quit_map].img = app.ctx.create_image(sprites_path + 'quit_map.png')!
		app.buttons[.flip_h].img = app.ctx.create_image(sprites_path + 'flip_h.png')!
		app.buttons[.flip_v].img = app.ctx.create_image(sprites_path + 'flip_v.png')!
		app.buttons[.selection_delete].img = app.ctx.create_image(sprites_path +
			'selection_delete.png')!
	}
	app.solo_img = app.ctx.create_image(sprites_path + 'nots_icon.png')!
	app.load_palette()
	app.ctx.run()
}

fn toml_palette_color(color string, doc toml.Doc) gg.Color {
	a := doc.value(color).array()
	return gg.Color{u8(a[0].u64()), u8(a[1].u64()), u8(a[2].u64()), u8(a[3].u64())}
}

fn (mut app App) load_palette() {
	doc := toml.parse_file(palette_path) or {
		app.log('Loading palette: ${err}')
		return
	}
	app.palette.junc = toml_palette_color('junc', doc)
	app.palette.junc_v = toml_palette_color('junc_v', doc)
	app.palette.junc_h = toml_palette_color('junc_h', doc)
	app.palette.wire_on = toml_palette_color('wire_on', doc)
	app.palette.wire_off = toml_palette_color('wire_off', doc)
	app.palette.on = toml_palette_color('on', doc)
	app.palette.not = toml_palette_color('not', doc)
	app.palette.diode = toml_palette_color('diode', doc)
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
	app.draw_count = 1
	size := app.ctx.window_size()
	// Draw
	app.ctx.begin()
	app.ctx.end() // to clear the screen
	if app.comp_running {
		app.draw_map()

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

		if !app.colorchips_hidden {
			for cc in app.colorchips {
				// TODO: compute the index of the color w/ the inputs
				/*
struct ColorChip { // TODO: save color chips and keyboard inputs too
	x u32
	y u32
	w u32
	h u32
mut:
	colors []gg.Color // colors to show
	inputs [][2]u32   // the state will be converted to a number (binary) and it will be the index of the shown color
}
				*/
				pos_x := f32((f64(cc.x) - app.cam_x) * app.tile_size)
				pos_y := f32((f64(cc.y) - app.cam_y) * app.tile_size)
				end_pos_x := f32((f64(cc.w) - app.cam_x) * app.tile_size)
				end_pos_y := f32((f64(cc.h) - app.cam_y) * app.tile_size)
				app.ctx.draw_rect_filled(pos_x, pos_y, end_pos_x, end_pos_y, app.palette.selection_box)
			}
		}

		compute_info := '${app.nb_updates}/s = ${int(time.second / app.nb_updates) / 1_000_000}ms/update (required:${app.avg_update_time / 1_000_000.0:.2f}ms)'
		coords_info := 'x:${i64(app.cam_x)} y:${i64(app.cam_y)}'
		app.ctx.draw_text_def(int(app.ui_width + 10), 10, app.map_name)
		app.ctx.draw_text_def(int(app.ui_width + 10), 30, compute_info)
		app.ctx.draw_text_def(int(app.ui_width + 10), 50, coords_info)

		if app.save_gate_mode {
			app.ctx.draw_rect_filled(app.ui_width + 10, 10, 250, 40, app.palette.ui_bg)
			app.ctx.draw_text_def(int(app.ui_width + 15), 20, 'Save gate: ${app.text_input}')
		}
		if app.load_gate_mode {
			app.ctx.draw_rect_filled(app.ui_width + 10, 10, 250, 40, app.palette.ui_bg)
			app.ctx.draw_text_def(int(app.ui_width + 15), 20, 'Load gate: ${app.text_input}')
			// search results

			app.gate_name_list = os.ls(gates_path) or {
				app.log('cannot list files in ${gates_path}, ${err}')
				[]string{}
			}
			x := app.ui_width + app.gate_x_ofst
			w := app.ui_width + app.gate_x_ofst + app.gate_w
			h := app.gate_top_spacing + app.gate_h
			for pos, name in app.gate_name_list.filter(it.contains(app.text_input)) { // the maps are filtered with the search field
				app.ctx.draw_rect_filled(x, pos * h + app.gate_y_offset, w, app.gate_h,
					app.palette.ui_bg)
				app.ctx.draw_text_def(int(x), int(pos * h + app.gate_y_offset + 10), name)
			}
		}
	} else if app.main_menu {
		app.ctx.draw_image(app.button_solo_x, app.button_solo_y, app.button_solo_w, app.button_solo_h,
			app.solo_img)
		unsafe {
			app.ctx.draw_image(app.btn_quit_ofst, app.button_solo_h + app.btn_quit_ofst,
				app.button_quit_size, app.button_quit_size, app.buttons[.quit_map].img)
		}
	} else if app.solo_menu {
		for i, m in app.map_names_list.filter(it.contains(app.text_input)) { // the maps are filtered with the search field
			app.ctx.draw_rect_filled(app.maps_x_offset, (app.maps_y_offset + app.maps_top_spacing) * (
				i + 1), app.maps_w, app.maps_h, app.palette.ui_bg)
			app.ctx.draw_text_def(int(app.maps_x_offset), int((app.maps_y_offset +
				app.maps_top_spacing) * (i + 1)), m)
		}
		app.ctx.draw_square_filled(app.button_new_map_x, app.button_new_map_y, app.button_new_map_size,
			app.palette.ui_bg)
		unsafe {
			app.ctx.draw_image(app.btn_back_x, app.btn_back_y, app.btn_back_s, app.btn_back_s,
				app.buttons[.cancel_button].img)
		}
		app.ctx.draw_text_def(int(app.text_field_x), int(app.text_field_y), app.text_input)
	} else {
		app.disable_all_ingame_modes()
		app.ctx.draw_square_filled(0, 0, 10, gg.Color{255, 0, 0, 255})
		app.log('Not implemented on_frame UI')
	}
	if app.log_timer > 0 {
		app.ctx.draw_text_def(int(app.ui_width + 10), size.height - 20, app.log)
		app.log_timer -= 1
	}
	app.ctx.end(how: .passthru)
}

fn (mut app App) draw_ingame_ui_buttons() {
	base_x := app.button_left_padding
	base_y := app.button_top_padding
	size := app.button_size
	y_factor := app.button_top_padding + size
	app.ctx.draw_rect_filled(0, 0, app.ui_width, 5000, app.palette.ui_bg)
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
				app.ctx.draw_image(base_x, app.buttons[button].pos * y_factor + base_y,
					size, size, app.buttons[button].img)
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

// inputs for colorchips
fn (mut app App) draw_input_buttons() {
	for key in app.key_pos.keys() {
		for pos in app.key_pos[key] {
			pos_x := f32(f64(pos[0] * u32(app.tile_size)) - app.cam_x)
			pos_y := f32(f64(pos[1] * u32(app.tile_size)) - app.cam_y)
			app.ctx.draw_square_filled(pos_x, pos_y, app.tile_size, app.palette.input_preview)
			// TODO: draw_text
		}
	}
	if app.tmp_pos_x != u32(-1) && app.tmp_pos_y != u32(-1) {
		pos_x := f32(f64(app.tmp_pos_x * u32(app.tile_size)) - app.cam_x)
		pos_y := f32(f64(app.tmp_pos_y * u32(app.tile_size)) - app.cam_y)
		app.ctx.draw_square_filled(pos_x, pos_y, app.tile_size, app.palette.input_preview)
	}
}

fn (mut app App) draw_placing_preview() {
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
			pos_x := f32((f64(x) - app.cam_x) * app.tile_size)
			pos_y := f32((f64(y) - app.cam_y) * app.tile_size)
			app.ctx.draw_square_filled(pos_x, pos_y, app.tile_size, app.palette.place_preview)
			app.draw_count += 1
		}
	}
}

fn (mut app App) draw_paste_preview() {
	// map rendering
	not_poly := app.scale_sprite(not_poly_unscaled)
	not_rect := app.scale_sprite(not_rect_unscaled)
	mut not_poly_offset := []f32{len: 6, cap: 6}
	diode_poly := app.scale_sprite(diode_poly_unscaled)
	mut diode_poly_offset := []f32{len: 8, cap: 8}
	on_poly := app.scale_sprite(on_poly_unscaled)
	mut on_poly_offset := []f32{len: 8, cap: 8}

	for pi in app.copied {
		pos_x := f32((f64(pi.rel_x) + f64(app.mouse_map_x) - app.cam_x) * app.tile_size)
		pos_y := f32((f64(pi.rel_y) + f64(app.mouse_map_y) - app.cam_y) * app.tile_size)
		orient := u64(pi.orientation) << 56
		if app.draw_count >= app.draw_step {
			app.ctx.end(how: .passthru)
			app.ctx.begin()
			app.draw_count = 1
		}
		if pi.elem == .crossing { // same bits as wires so need to be separated
			app.ctx.draw_square_filled(pos_x, pos_y, app.tile_size, app.palette.junc)
			app.ctx.draw_rect_filled(pos_x, pos_y + app.tile_size / 3, app.tile_size,
				app.tile_size / 3, app.palette.junc_h)
			app.ctx.draw_rect_filled(pos_x + app.tile_size / 3, pos_y, app.tile_size / 3,
				app.tile_size, app.palette.junc_v)
			app.draw_count += 3
		} else {
			state_color, not_state_color := app.palette.wire_off, app.palette.wire_on

			ori := match orient {
				north { 0 }
				south { 1 }
				west { 2 }
				east { 3 }
				else { app.log_quit('${@LOCATION} should not get into this else') }
			}
			match pi.elem {
				.not {
					app.ctx.draw_square_filled(pos_x, pos_y, app.tile_size, app.palette.not)
					not_poly_offset[0] = not_poly[ori][0] + pos_x
					not_poly_offset[1] = not_poly[ori][1] + pos_y
					not_poly_offset[2] = not_poly[ori][2] + pos_x
					not_poly_offset[3] = not_poly[ori][3] + pos_y
					not_poly_offset[4] = not_poly[ori][4] + pos_x
					not_poly_offset[5] = not_poly[ori][5] + pos_y
					app.ctx.draw_convex_poly(not_poly_offset, not_state_color)
					app.ctx.draw_rect_filled(not_rect[ori][0] + pos_x, not_rect[ori][1] + pos_y,
						not_rect[ori][2], not_rect[ori][3], state_color)
					app.draw_count += 3
				}
				.diode {
					app.ctx.draw_square_filled(pos_x, pos_y, app.tile_size, app.palette.diode)
					diode_poly_offset[0] = diode_poly[ori][0] + pos_x
					diode_poly_offset[1] = diode_poly[ori][1] + pos_y
					diode_poly_offset[2] = diode_poly[ori][2] + pos_x
					diode_poly_offset[3] = diode_poly[ori][3] + pos_y
					diode_poly_offset[4] = diode_poly[ori][4] + pos_x
					diode_poly_offset[5] = diode_poly[ori][5] + pos_y
					diode_poly_offset[6] = diode_poly[ori][6] + pos_x
					diode_poly_offset[7] = diode_poly[ori][7] + pos_y
					app.ctx.draw_convex_poly(diode_poly_offset, state_color)
					app.draw_count += 2
				}
				.on {
					app.ctx.draw_square_filled(pos_x, pos_y, app.tile_size, app.palette.on)
					on_poly_offset[0] = on_poly[ori][0] + pos_x
					on_poly_offset[1] = on_poly[ori][1] + pos_y
					on_poly_offset[2] = on_poly[ori][2] + pos_x
					on_poly_offset[3] = on_poly[ori][3] + pos_y
					on_poly_offset[4] = on_poly[ori][4] + pos_x
					on_poly_offset[5] = on_poly[ori][5] + pos_y
					on_poly_offset[6] = on_poly[ori][6] + pos_x
					on_poly_offset[7] = on_poly[ori][7] + pos_y
					app.ctx.draw_convex_poly(on_poly_offset, app.palette.wire_on)
					app.draw_count += 2
				}
				.wire {
					app.ctx.draw_square_filled(pos_x, pos_y, app.tile_size, state_color)
					app.draw_count += 1
				}
				else {
					app.log_quit('${@LOCATION} should not get into this else')
				}
			}
		}
		app.ctx.draw_square_filled(pos_x, pos_y, app.tile_size, app.palette.copy_preview)
		app.draw_count += 1
	}
}

fn (mut app App) draw_selection_box() {
	if app.select_start_x != u32(-1) {
		pos_x := f32((f64(app.select_start_x) - app.cam_x) * app.tile_size)
		pos_y := f32((f64(app.select_start_y) - app.cam_y) * app.tile_size)
		app.ctx.draw_square_filled(pos_x, pos_y, app.tile_size, app.palette.selection_start)
	}
	if app.select_end_x != u32(-1) {
		pos_x := f32((f64(app.select_end_x) - app.cam_x) * app.tile_size)
		pos_y := f32((f64(app.select_end_y) - app.cam_y) * app.tile_size)
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
		pos_x := f32((f64(x_start) - app.cam_x) * app.tile_size)
		pos_y := f32((f64(y_start) - app.cam_y) * app.tile_size)
		end_pos_w := f32((f64(x_end + 1) - app.cam_x) * app.tile_size) - pos_x
		end_pos_h := f32((f64(y_end + 1) - app.cam_y) * app.tile_size) - pos_y
		app.ctx.draw_rect_filled(pos_x, pos_y, end_pos_w, end_pos_h, app.palette.selection_box)
	}
}

fn (mut app App) draw_map() {
	size := app.ctx.window_size()
	// map rendering
	not_poly := app.scale_sprite(not_poly_unscaled)
	not_rect := app.scale_sprite(not_rect_unscaled)
	mut not_poly_offset := []f32{len: 6, cap: 6}
	diode_poly := app.scale_sprite(diode_poly_unscaled)
	mut diode_poly_offset := []f32{len: 8, cap: 8}
	on_poly := app.scale_sprite(on_poly_unscaled)
	mut on_poly_offset := []f32{len: 8, cap: 8}
	virt_cam_x := app.cam_x - (app.drag_x - app.click_x) / app.tile_size
	virt_cam_y := app.cam_y - (app.drag_y - app.click_y) / app.tile_size
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
	for chunk in app.map {
		chunk_cam_x := chunk.x - virt_cam_x
		chunk_cam_y := chunk.y - virt_cam_y
		if chunk_cam_x > -chunk_size && chunk_cam_x < size.width && chunk_cam_y > -chunk_size
			&& chunk_cam_y < size.height {
			for x, column in chunk.id_map {
				pos_x := f32((chunk_cam_x + x) * app.tile_size)
				if pos_x < size.width { // cant break like that for lower bound
					for y, id in column {
						if id == empty_id {
							continue
						}
						pos_y := f32((chunk_cam_y + y) * app.tile_size)
						if pos_y < size.height {
							if pos_y > -chunk_size * app.tile_size
								&& pos_x > -chunk_size * app.tile_size {
								if app.draw_count >= app.draw_step {
									app.ctx.end(how: .passthru)
									app.ctx.begin()
									app.draw_count = 1
								}
								app.draw_count += 1
								if id == elem_crossing_bits { // same bits as wires so need to be separated
									app.ctx.draw_square_filled(pos_x, pos_y, app.tile_size,
										app.palette.junc)
									app.draw_count += 1
									if app.tile_size >= 10 {
										app.ctx.draw_rect_filled(pos_x, pos_y + app.tile_size / 3,
											app.tile_size, app.tile_size / 3, app.palette.junc_h)
										app.ctx.draw_rect_filled(pos_x + app.tile_size / 3,
											pos_y, app.tile_size / 3, app.tile_size, app.palette.junc_v)
										app.draw_count += 2
									}
								} else {
									state_color, not_state_color := if id & on_bits == 0 {
										app.palette.wire_off, app.palette.wire_on
									} else {
										app.palette.wire_on, app.palette.wire_off
									}
									ori := match id & ori_mask {
										north { 0 }
										south { 1 }
										west { 2 }
										east { 3 }
										else { app.log_quit('${@LOCATION} should not get into this else') }
									}
									match id & elem_type_mask {
										elem_not_bits {
											app.ctx.draw_square_filled(pos_x, pos_y, app.tile_size,
												app.palette.not)
											app.draw_count += 1
											if app.tile_size >= 5 {
												not_poly_offset[0] = not_poly[ori][0] + pos_x
												not_poly_offset[1] = not_poly[ori][1] + pos_y
												not_poly_offset[2] = not_poly[ori][2] + pos_x
												not_poly_offset[3] = not_poly[ori][3] + pos_y
												not_poly_offset[4] = not_poly[ori][4] + pos_x
												not_poly_offset[5] = not_poly[ori][5] + pos_y
												app.ctx.draw_convex_poly(not_poly_offset,
													not_state_color)
												app.ctx.draw_rect_filled(not_rect[ori][0] + pos_x,
													not_rect[ori][1] + pos_y, not_rect[ori][2],
													not_rect[ori][3], state_color)
												app.draw_count += 2
											}
										}
										elem_diode_bits {
											app.ctx.draw_square_filled(pos_x, pos_y, app.tile_size,
												app.palette.diode)
											app.draw_count += 1
											if app.tile_size >= 5 {
												diode_poly_offset[0] = diode_poly[ori][0] + pos_x
												diode_poly_offset[1] = diode_poly[ori][1] + pos_y
												diode_poly_offset[2] = diode_poly[ori][2] + pos_x
												diode_poly_offset[3] = diode_poly[ori][3] + pos_y
												diode_poly_offset[4] = diode_poly[ori][4] + pos_x
												diode_poly_offset[5] = diode_poly[ori][5] + pos_y
												diode_poly_offset[6] = diode_poly[ori][6] + pos_x
												diode_poly_offset[7] = diode_poly[ori][7] + pos_y
												app.ctx.draw_convex_poly(diode_poly_offset,
													state_color)
												app.draw_count += 1
											}
										}
										elem_on_bits {
											app.ctx.draw_square_filled(pos_x, pos_y, app.tile_size,
												app.palette.on)
											app.draw_count += 1
											if app.tile_size >= 5 {
												on_poly_offset[0] = on_poly[ori][0] + pos_x
												on_poly_offset[1] = on_poly[ori][1] + pos_y
												on_poly_offset[2] = on_poly[ori][2] + pos_x
												on_poly_offset[3] = on_poly[ori][3] + pos_y
												on_poly_offset[4] = on_poly[ori][4] + pos_x
												on_poly_offset[5] = on_poly[ori][5] + pos_y
												on_poly_offset[6] = on_poly[ori][6] + pos_x
												on_poly_offset[7] = on_poly[ori][7] + pos_y
												app.ctx.draw_convex_poly(on_poly_offset,
													app.palette.wire_on)
												app.draw_count += 1
											}
										}
										elem_wire_bits {
											app.ctx.draw_square_filled(pos_x, pos_y, app.tile_size,
												state_color)
											app.draw_count += 1
										}
										else {
											app.log_quit('${@LOCATION} should not get into this else')
										}
									}
								}
							}
						} else {
							break
						}
					}
				} else {
					break
				}
			}
		}
	}
}

fn (app App) check_ui_button_click_y(but Buttons, mouse_y f32) bool {
	pos := unsafe { app.buttons[but].pos }
	return mouse_y >= pos * (app.button_top_padding + app.button_size) + app.button_top_padding
		&& mouse_y < (pos + 1) * (app.button_top_padding + app.button_size) + app.button_top_padding
}

fn (app App) ingame_ui_button_click_to_nb(mouse_x f32, mouse_y f32) int {
	if !(mouse_x >= app.button_left_padding && mouse_x < app.button_size + app.button_left_padding) { // button area
		return -1
	}
	return int((mouse_y - app.button_top_padding) / (app.button_top_padding + app.button_size))
}

fn (mut app App) handle_ingame_ui_button_interrac(b Buttons) {
	if b == .cancel_button {
		app.disable_all_ingame_modes()
		app.tmp_pos_x = u32(-1)
		app.tmp_pos_y = u32(-1)
		app.create_colorchip_x = u32(-1)
		app.create_colorchip_endx = u32(-1)
		app.place_start_x = u32(-1)
		app.text_input = ''
	} else if b == .edit_color {
		if app.selected_colorchip == -1 {
			app.log('No ColorChip selected')
		} else {
			app.disable_all_ingame_modes()
			app.colorchips_hidden = false
			app.edit_color_submode = true
		}
	} else if b == .choose_colorchip {
		app.disable_all_ingame_modes()
		app.choose_colorchip_submode = true
	} else if b == .create_color_chip {
		app.disable_all_ingame_modes()
		app.colorchips_hidden = false
		app.create_colorchip_submode = true
	} else if b == .add_input {
		if app.selected_colorchip == -1 {
			app.log('No ColorChip selected')
		} else {
			app.disable_all_ingame_modes()
			app.colorchips_hidden = true
			app.add_input_submode = true
		}
	} else if b == .steal_settings {
		if app.selected_colorchip == -1 {
			app.log('No ColorChip selected')
		} else {
			app.disable_all_ingame_modes()
			app.colorchips_hidden = false
			app.steal_settings_submode = true
		}
	} else if b == .delete_colorchip {
		app.disable_all_ingame_modes()
		app.colorchips_hidden = false
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
		if app.e.modifiers & 1 == 1 { // shift: 1<<0
			app.todo << TodoInfo{.rotate, 0, 0, 0, 0, ''}
		} else {
			app.todo << TodoInfo{.rotate, 0, 0, 0, 0, ''} // TODO: rotate_right, maybe could use one of the fields
			app.todo << TodoInfo{.rotate, 0, 0, 0, 0, ''}
			app.todo << TodoInfo{.rotate, 0, 0, 0, 0, ''}
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
				app.log('Gate ${app.text_input} already exists')
			}
		}
	} else if b == .copy_button {
		if app.select_start_x != u32(-1) && app.select_end_x != u32(-1) {
			app.todo << TodoInfo{.copy, app.select_start_x, app.select_start_y, app.select_end_x, app.select_end_y, ''}
			app.log('Copied selection')
		}
	} else if b == .selection_delete {
		app.todo << TodoInfo{.removal, app.select_start_x, app.select_start_y, app.select_end_x, app.select_end_y, ''}
	} else if b == .paste {
		app.disable_all_ingame_modes()
		app.paste_mode = true
	} else if b == .save_gate {
		app.disable_all_ingame_modes()
		app.save_gate_mode = true
		app.text_input = ''
	} else if b == .create_color_chip {
		if app.select_start_x != u32(-1) && app.select_start_y != u32(-1)
			&& app.select_end_x != u32(-1) && app.select_end_y != u32(-1) {
			app.disable_all_ingame_modes()
			app.create_colorchip_submode = true
			app.create_colorchip_x = u32(-1)
			app.create_colorchip_y = u32(-1)
			app.create_colorchip_endx = u32(-1)
			app.create_colorchip_endy = u32(-1)
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
		for app.todo.len > 0 {} // wait
	} else if b == .quit_map {
		app.quit_map()
	} else if b == .hide_colorchips {
		app.colorchips_hidden = !app.colorchips_hidden
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
	return mouse_y >= pos * (app.maps_top_spacing + app.maps_h) + app.maps_y_offset
		&& mouse_y < (pos + 1) * (app.maps_top_spacing + app.maps_h) + app.maps_y_offset
}

fn (app App) check_gates_button_click_y(pos int, mouse_y f32) bool {
	return mouse_y >= pos * (app.gate_top_spacing + app.gate_h) + app.gate_y_offset
		&& mouse_y < (pos + 1) * (app.gate_top_spacing + app.gate_h) + app.gate_y_offset
}

fn (mut app App) disable_all_ingame_modes() {
	app.edit_mode = false
	app.steal_settings_submode = false
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
}

fn (mut app App) go_map_menu() {
	app.main_menu = false
	app.solo_menu = true
	app.text_input = ''
	if !os.exists(maps_path) {
		os.mkdir(maps_path) or {
			app.log('Cannot create ${maps_path}, ${err}')
			return
		}
	}
	if !os.exists(gates_path) { // this one too in case
		os.mkdir(gates_path) or {
			app.log('Cannot create ${maps_path}, ${err}')
			return
		}
	}
	app.map_names_list = os.ls(maps_path) or {
		app.log('Cannot list files in ${maps_path}, ${err}')
		return
	}
}

fn (mut app App) load_saved_game(name string) {
	dump('load_saved_game')
	/// server side
	app.load_map(name) or {
		app.log('Cannot load map ${name}, ${err}')
		return
	}
	app.map_name = name
	app.pause = false
	app.nb_updates = 5
	app.todo = []
	app.selected_item = .not
	app.selected_ori = north
	app.copied = []
	app.actual_state = 0
	app.comp_running = true
	///
	app.solo_menu = false
	app.text_input = ''
	spawn app.computation_loop()
	app.cam_x = default_camera_pos_x
	app.cam_y = default_camera_pos_y
}

fn (mut app App) create_game() {
	dump('create_game')
	if !os.exists(maps_path + app.text_input) || true { // TODO
		app.disable_all_ingame_modes()
		app.solo_menu = false
		/// serverside
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
		///
		println('starting computation!!!')
		spawn app.computation_loop()
		app.cam_x = default_camera_pos_x
		app.cam_y = default_camera_pos_y
	} else {
		app.log('Map ${app.text_input} already exists')
	}
}

fn (mut app App) back_to_main_menu() {
	app.disable_all_ingame_modes()
	app.solo_menu = false
	app.main_menu = true
}

fn (mut app App) check_and_delete_colorchip_input(mouse_x f32, mouse_y f32) {
	for i in 0 .. app.colorchips[app.selected_colorchip].inputs.len {
		x := app.editmenu_offset_inputs_x +
			i % app.editmenu_nb_inputs_by_row * app.editmenu_inputsize
		y := app.editmenu_offset_inputs_y +
			i / app.editmenu_nb_inputs_by_row * app.editmenu_inputsize
		if mouse_x >= x && mouse_x < x + app.editmenu_inputsize {
			if mouse_y >= y && mouse_y < y + app.editmenu_inputsize {
				app.colorchips[app.selected_colorchip].inputs.delete(i)
				for app.colorchips[app.selected_colorchip].colors.len > pow(2, app.colorchips[app.selected_colorchip].inputs.len) {
					app.colorchips[app.selected_colorchip].colors.delete(app.colorchips[app.selected_colorchip].colors.len - 1)
				}
			}
		}
	}
}

fn (mut app App) check_and_select_or_delete_color_cc(mouse_x f32, mouse_y f32, e &gg.Event) {
	for i in 0 .. app.colorchips[app.selected_colorchip].colors.len {
		x := app.editmenu_offset_x + i % app.editmenu_nb_color_by_row * app.editmenu_colorsize
		y := app.editmenu_offset_y + i / app.editmenu_nb_color_by_row * app.editmenu_colorsize
		if mouse_x >= x && mouse_x < x + app.editmenu_colorsize {
			if mouse_y >= y && mouse_y < y + app.editmenu_colorsize {
				if e.mouse_button == .left {
					app.editmenu_selected_color = i
				} else if e.mouse_button == .right {
					app.colorchips[app.selected_colorchip].colors.delete(i)
					app.editmenu_selected_color -= 1
					if app.editmenu_selected_color < 0 {
						app.editmenu_selected_color = 0
					}
					for app.colorchips[app.selected_colorchip].colors.len < pow(2, app.colorchips[app.selected_colorchip].inputs.len) {
						app.colorchips[app.selected_colorchip].colors << gg.Color{0, 0, 0, 255}
					}
				}
			}
		}
	}
}

fn (mut app App) check_and_change_color_cc(mouse_x f32, mouse_y f32, e &gg.Event) {
	if mouse_y >= app.editmenu_rgb_y && mouse_y < app.editmenu_rgb_y + app.editmenu_rgb_h {
		if mouse_x >= app.editmenu_r_x && mouse_x < app.editmenu_r_x + app.editmenu_rgb_w {
			if e.mouse_button == .left {
				app.colorchips[app.selected_colorchip].colors[app.editmenu_selected_color].r += 1
			} else if e.mouse_button == .right {
				app.colorchips[app.selected_colorchip].colors[app.editmenu_selected_color].r -= 1
			}
		}
		if mouse_x >= app.editmenu_g_x && mouse_x < app.editmenu_g_x + app.editmenu_rgb_w {
			if e.mouse_button == .left {
				app.colorchips[app.selected_colorchip].colors[app.editmenu_selected_color].g += 1
			} else if e.mouse_button == .right {
				app.colorchips[app.selected_colorchip].colors[app.editmenu_selected_color].g -= 1
			}
		}
		if mouse_x >= app.editmenu_b_x && mouse_x < app.editmenu_b_x + app.editmenu_rgb_w {
			if e.mouse_button == .left {
				app.colorchips[app.selected_colorchip].colors[app.editmenu_selected_color].b += 1
			} else if e.mouse_button == .right {
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

fn (mut app App) create_colorchip_with_end_at(mouse_x f32, mouse_y f32) {
	app.create_colorchip_endx = u32(app.cam_x + (mouse_x / app.tile_size))
	app.create_colorchip_endy = u32(app.cam_y + (mouse_y / app.tile_size))
	if app.create_colorchip_x > app.create_colorchip_endx {
		app.create_colorchip_x, app.create_colorchip_endx = app.create_colorchip_endx, app.create_colorchip_x
	}
	if app.create_colorchip_y > app.create_colorchip_endy {
		app.create_colorchip_y, app.create_colorchip_endy = app.create_colorchip_endy, app.create_colorchip_y
	}
	app.colorchips << ColorChip{
		x:      app.create_colorchip_x
		y:      app.create_colorchip_y
		w:      app.create_colorchip_endx - app.create_colorchip_x
		h:      app.create_colorchip_endy - app.create_colorchip_y
		colors: [default_colorchip_color_on, default_colorchip_color_off]
	}
	app.create_colorchip_x = u32(-1)
	app.create_colorchip_endx = u32(-1)
	app.create_colorchip_y = u32(-1)
	app.create_colorchip_endy = u32(-1)
	app.selected_colorchip = app.colorchips.len - 1
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
	dump('quit_map')
	app.disable_all_ingame_modes()
	app.todo << TodoInfo{.quit, 0, 0, 0, 0, app.map_name}
	dump('waiting for save')
	for app.comp_alive {} // wait for quitting
	dump('finished save')
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

fn on_event(e &gg.Event, mut app App) {
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
	match e.typ {
		.mouse_up {
			app.mouse_down = false
			if app.main_menu {
				if mouse_x >= app.button_solo_x && mouse_x < app.button_solo_x + app.button_solo_w
					&& mouse_y >= app.button_solo_y
					&& mouse_y < app.button_solo_y + app.button_solo_h {
					app.go_map_menu()
				} else if mouse_x >= app.btn_quit_ofst
					&& mouse_x < app.btn_quit_ofst + app.button_quit_size
					&& mouse_y >= app.button_solo_h + app.btn_quit_ofst
					&& mouse_y < app.button_solo_h + app.btn_quit_ofst + app.button_quit_size {
					exit(0)
				}
			} else if app.solo_menu {
				if mouse_x >= app.maps_x_offset && mouse_x < app.maps_x_offset + app.maps_w {
					app.map_names_list = os.ls(maps_path) or {
						app.log('Cannot list files in ${maps_path}, ${err}')
						return
					}
					for i, name in app.map_names_list.filter(it.contains(app.text_input)) { // the maps are filtered with the search field
						if e.mouse_button == .left {
							if app.check_maps_button_click_y(i, mouse_y) {
								app.load_saved_game(name)
								return
							}
						}
					}
				}
				if app.text_input != '' && mouse_x >= app.button_new_map_x
					&& mouse_x < app.button_new_map_x + app.button_new_map_size
					&& mouse_y >= app.button_new_map_y
					&& mouse_y < app.button_new_map_y + app.button_new_map_size {
					app.create_game()
				} else if mouse_x >= app.btn_back_x && mouse_x < app.btn_back_x + app.btn_back_s
					&& mouse_y >= app.btn_back_y && mouse_y < app.btn_back_y + app.btn_back_s {
					app.back_to_main_menu()
				}
			} else if app.comp_running {
				if app.keyinput_mode {
					if mouse_x < app.ui_width {
						app.handle_ingame_ui_button_click(mouse_x, mouse_y)
					} else {
						map_x := app.cam_x + (mouse_x / app.tile_size)
						map_y := app.cam_y + (mouse_y / app.tile_size)
						// right click -> delete the pos = click_pos encountered in the map
						// left click -> waiting for input, when input, save pos & key in the map
						if e.mouse_button == .right {
							for key in app.key_pos.keys() {
								i := app.key_pos[key].index([u32(map_x), u32(map_y)]!)
								if i != -1 {
									app.key_pos[key].delete(i) // it will delete all the "buttons" on this tile, but the multiple buttons are not intended anyways				
								}
							}
						} else if e.mouse_button == .left {
							app.tmp_pos_x = u32(map_x) // TODO: show these too
							app.tmp_pos_y = u32(map_y)
						} else {
							app.tmp_pos_x = u32(-1)
							app.tmp_pos_y = u32(-1)
							// TODO: move, do this with other modes too, it's nice to move w/ middle click when having a mouse
						}
					}
				} else if app.edit_mode {
					if mouse_x < app.ui_width {
						app.handle_ingame_ui_button_click(mouse_x, mouse_y)
					} else {
						if app.edit_color_submode && app.selected_colorchip != -1 {
							app.check_and_delete_colorchip_input(mouse_x, mouse_y)
							app.check_and_select_or_delete_color_cc(mouse_x, mouse_y,
								e)
							app.check_and_change_color_cc(mouse_x, mouse_y, e)
						} else if app.delete_colorchip_submode {
							app.delete_colorchip_at(mouse_x, mouse_y)
						} else if app.create_colorchip_submode {
							if app.create_colorchip_x == u32(-1) {
								app.create_colorchip_x = u32(app.cam_x + (mouse_x / app.tile_size))
								app.create_colorchip_y = u32(app.cam_y + (mouse_y / app.tile_size))
							} else if app.create_colorchip_endx == u32(-1) {
								app.create_colorchip_with_end_at(mouse_x, mouse_y)
							}
						} else if app.add_input_submode && app.selected_colorchip != -1 {
							app.colorchips[app.selected_colorchip].inputs << [
								u32(app.cam_x + (mouse_x / app.tile_size)),
								u32(app.cam_y + (mouse_y / app.tile_size)),
							]!
							for app.colorchips[app.selected_colorchip].colors.len < pow(2,
								app.colorchips[app.selected_colorchip].inputs.len) {
							}
							app.disable_all_ingame_modes()
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
						} else if app.steal_settings_submode && app.selected_colorchip != -1 {
							map_x := u32(app.cam_x + (mouse_x / app.tile_size))
							map_y := u32(app.cam_y + (mouse_y / app.tile_size))
							for cc in app.colorchips {
								if map_x >= cc.x && map_x < cc.x + cc.w && map_y >= cc.y
									&& map_y < cc.y + cc.h {
									app.colorchips[app.selected_colorchip].colors = app.colorchips[app.selected_colorchip].colors.clone()
									break
								}
							}
						}
					}
				} else if app.load_gate_mode {
					if mouse_x < app.ui_width {
						app.handle_ingame_ui_button_click(mouse_x, mouse_y)
					} else {
						app.gate_name_list = os.ls(gates_path) or {
							app.log('cannot list files in ${gates_path}, ${err}')
							return
						}
						if mouse_x >= app.ui_width + app.gate_x_ofst
							&& mouse_x < app.ui_width + app.gate_x_ofst + app.gate_w {
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
					if app.place_down { // TODO: make the UI disappear/fade out when doing a placement
						app.placement_released_at(mouse_x, mouse_y, e)
					} else if mouse_x < app.ui_width {
						app.handle_ingame_ui_button_click(mouse_x, mouse_y)
					}
				} else if app.paste_mode {
					if mouse_x < app.ui_width {
						app.handle_ingame_ui_button_click(mouse_x, mouse_y)
					} else {
						if e.mouse_button == .left {
							app.todo << TodoInfo{.paste, u32(app.cam_x + mouse_x / app.tile_size), u32(
								app.cam_y + mouse_y / app.tile_size), 0, 0, ''}
						}
					}
				} else if app.save_gate_mode {
					if mouse_x < app.ui_width {
						app.handle_ingame_ui_button_click(mouse_x, mouse_y)
					}
				} else if app.selection_mode {
					if mouse_x < app.ui_width {
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
						app.move_down = false
						app.cam_x = app.cam_x - ((mouse_x - app.click_x) / app.tile_size)
						app.cam_y = app.cam_y - ((mouse_y - app.click_y) / app.tile_size)
						app.click_x = 0
						app.click_y = 0
						app.drag_x = 0
						app.drag_y = 0
					} else if mouse_x < app.ui_width {
						app.handle_ingame_ui_button_click(mouse_x, mouse_y)
					}
				}
			}
		}
		.mouse_down {
			app.mouse_down = true
		}
		.key_up {
			if app.keyinput_mode {
				if e.char_code != 0 {
					for pos in app.key_pos[u8(e.char_code)] {
						i := app.forced_states.index(pos)
						if i != -1 {
							app.forced_states.delete(i)
						}
					}
				}
			} else if app.selection_mode { // TODO: disable to not grief
				// TODO: pause the backend
				/*
				if e.key_code == .f {
					fuzz_cycles := 100
					/// /!\· interacts with the backend directly, to change TODO
					if app.select_start_x != u32(-1) && app.select_start_y != u32(-1)
						&& app.select_end_x != u32(-1) && app.select_end_y != u32(-1) {
						outer: for i in 0 .. 100 { // 100 gates
							println(i)
							app.removal(app.select_start_x, app.select_start_y, app.select_end_x,
								app.select_end_y)
							app.fuzz(app.select_start_x, app.select_start_y, app.select_end_x,
								app.select_end_y)
							for _ in 0 .. fuzz_cycles {
								app.update_cycle()
								x_err, y_err, str_err := app.test_validity(app.select_start_x,
									app.select_start_y, app.select_end_x, app.select_end_y)
								if str_err != '' {
									app.log('FAIL: (validity) ${str_err}')
									println('TODO:')
									println(x_err)
									println(y_err)
									// TODO: show the coords on screen (tp to the right place & color the square)
									break outer
								}
							}
						}
					}
				}
				*/
			}
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
	if e.char_code != 0 {
		if app.solo_menu {
			app.text_input += u8(e.char_code).ascii_str()
		} else if app.load_gate_mode {
			app.text_input += u8(e.char_code).ascii_str()
		} else if app.keyinput_mode {
			if app.tmp_pos_x == u32(-1) || app.tmp_pos_y == u32(-1) { // defensive: prevent map border
				app.forced_states << app.key_pos[u8(e.char_code)]
			} else {
				if mut a := app.key_pos[u8(e.char_code)] {
					a << [app.tmp_pos_x, app.tmp_pos_y]!
				} else {
					app.key_pos[u8(e.char_code)] = [
						[app.tmp_pos_x, app.tmp_pos_y]!,
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
				if mouse_x <= app.ui_width {
				} else {
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
			} else if app.selection_mode {
				if mouse_x <= app.ui_width {
				} else {
					if e.mouse_button == .left {
						app.select_start_x = u32(app.cam_x + mouse_x / app.tile_size)
						app.select_start_y = u32(app.cam_y + mouse_y / app.tile_size)
					} else if e.mouse_button == .right {
						app.select_end_x = u32(app.cam_x + mouse_x / app.tile_size)
						app.select_end_y = u32(app.cam_y + mouse_y / app.tile_size)
					}
				}
			} else if app.paste_mode {
			} else if app.load_gate_mode {
			} else {
				if mouse_x <= app.ui_width {
				} else {
					if !app.move_down {
						app.move_down = true
						app.click_x = mouse_x
						app.click_y = mouse_y
					}
					app.drag_x = mouse_x
					app.drag_y = mouse_y
				}
			}
		}
	}
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
	// TODO: show on screen
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
			app.set_elem_state_by_pos(pos[0], pos[1], true)
		}
		cycle_end = time.now().unix_nano() + i64(1_000_000_000.0 / f32(app.nb_updates)) - i64(app.avg_update_time) // nanosecs
		mut done := []int{}
		for i, todo in app.todo {
			now = time.now().unix_nano()
			if now < cycle_end || i == 0 {
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
		if app.todo.len == 0 && cycle_end - now >= 10000 { // 10micro sec
			gc_disable()
			time.sleep((cycle_end - now) * time.nanosecond)
			gc_enable()
		}

		now = time.now().unix_nano()
		if !app.pause && app.comp_running {
			app.update_cycle()
		}
		app.avg_update_time = f32(time.now().unix_nano() - now) * 0.1 + 0.9 * app.avg_update_time
	}
	app.comp_alive = false
}

fn (mut app App) save_copied(name_ string) ! {
	mut name := name_
	if os.exists(gates_path) {
		for os.exists(gates_path + name) {
			name += 'New'
		}
		mut file := os.open_file(gates_path + name, 'w')!
		unsafe { file.write_ptr(app.copied.data, app.copied.len * int(sizeof(PlaceInstruction))) } // TODO : get the output nb and log it -> successful or not?
		file.close()
	}
}

fn (mut app App) load_map(map_name string) ! {
	// u32(version)
	//
	// i64(app.map.len)
	// for each chunk:
	// 	chunk.x chunk.y
	// 	chunk's content
	//
	// actual_state (which array)
	//
	// i64(app.nots.len)
	// all the nots (their data)
	// nots' state array
	//
	// i64(app.diodes.len)
	// all the diodes (their data)
	// diode's state array
	//
	// i64(app.wires.len)
	// for each wire:
	// 	rid
	//	i64(wire.inps.len)
	//	all the inputs
	//	i64(wire.outs.len)
	//	all the outputs
	//	i64(wire.cable_coords.len)
	// 	for all the cables:
	// 	cable.x  cable.y
	// wire's state array
	//
	// i64(app.forced_states.len)
	// forced_states ([2]u32)
	//
	// i64(app.colorchips.len)
	// for each cc:
	// 	x, y, w, h
	//	i64(cc.colors.len)
	//	colors gg.Color r g b
	//	i64(cc.inputs.len)
	//	inputs [2]u32

	if os.exists(maps_path) {
		dump('heyy')
		mut f := os.open(maps_path + map_name)!
		assert f.read_raw[u32]()! == 0
		map_len := f.read_raw[i64]()!
		app.map = []
		mut new_c := Chunk{}
		for _ in 0 .. map_len {
			f.read_struct(mut new_c)!
			app.map << new_c
		}
		dump('Chunkmap')
		app.actual_state = f.read_raw[int]()!

		nots_len := f.read_raw[i64]()!
		mut new_n := Nots{}
		app.nots = []
		for _ in 0 .. nots_len {
			f.read_struct(mut new_n)!
			app.nots << new_n
		}
		app.n_states[app.actual_state] = []bool{len: int(nots_len)} // to have an array in a good shape
		f.read_into_ptr(app.n_states[app.actual_state].data, int(nots_len))!
		app.n_states[(app.actual_state + 1) / 2] = []bool{len: int(nots_len)}
		dump('Nots')
		diodes_len := f.read_raw[i64]()!
		mut new_d := Diode{}
		app.diodes = []
		for _ in 0 .. diodes_len {
			f.read_struct(mut new_d)!
			app.diodes << new_d
		}
		app.d_states[app.actual_state] = []bool{len: int(diodes_len)}
		f.read_into_ptr(app.d_states[app.actual_state].data, int(diodes_len))!
		app.d_states[(app.actual_state + 1) / 2] = []bool{len: int(diodes_len)}
		dump('Didodes')
		wires_len := f.read_raw[i64]()!
		app.wires = []
		for _ in 0 .. wires_len {
			mut new_w := Wire{
				rid: f.read_raw[u64]()!
			}
			inps_len := f.read_raw[i64]()!
			for _ in 0 .. inps_len {
				new_w.inps << f.read_raw[u64]()!
			}
			outs_len := f.read_raw[i64]()!
			for _ in 0 .. outs_len {
				new_w.outs << f.read_raw[u64]()!
			}
			cable_len := f.read_raw[i64]()!
			for _ in 0 .. cable_len {
				new_w.cable_coords << [f.read_raw[u32]()!, f.read_raw[u32]()!]!
			}
			app.wires << new_w
		}
		app.w_states[app.actual_state] = []bool{len: int(wires_len)}
		f.read_into_ptr(app.w_states[app.actual_state].data, int(wires_len))!
		app.w_states[(app.actual_state + 1) / 2] = []bool{len: int(wires_len)}
		dump('Wires')
		forced_states_len := f.read_raw[i64]()!
		dump(forced_states_len)
		app.forced_states = []
		for _ in 0 .. forced_states_len {
			app.forced_states << [f.read_raw[u32]()!, f.read_raw[u32]()!]!
		}
		dump('forced states')
		colorchips_len := f.read_raw[i64]()!
		dump(colorchips_len)
		app.colorchips = []
		for _ in 0 .. colorchips_len {
			mut new_cc := ColorChip{
				x: f.read_raw[u32]()!
				y: f.read_raw[u32]()!
				w: f.read_raw[u32]()!
				h: f.read_raw[u32]()!
			}
			colors_len := f.read_raw[i64]()!
			dump(colors_len)
			for _ in 0 .. colors_len {
				new_cc.colors << gg.Color{f.read_raw[u8]()!, f.read_raw[u8]()!, f.read_raw[u8]()!, 255}
			}
			inputs_len := f.read_raw[i64]()!
			dump(inputs_len)
			for _ in 0 .. inputs_len {
				new_cc.inputs << [f.read_raw[u32]()!, f.read_raw[u32]()!]!
			}
		}
		dump('Done!')
		f.close()
	}
}

fn (mut app App) save_map(map_name string) ! {
	// u32(version)
	//
	// i64(app.map.len)
	// for each chunk:
	// 	chunk.x chunk.y
	// 	chunk's content
	//
	// actual_state (which array)
	//
	// i64(app.nots.len)
	// all the nots (their data)
	// nots' state array
	//
	// i64(app.diodes.len)
	// all the diodes (their data)
	// diode's state array
	//
	// i64(app.wires.len)
	// for each wire:
	// 	rid
	//	i64(wire.inps.len)
	//	all the inputs
	//	i64(wire.outs.len)
	//	all the outputs
	//	i64(wire.cable_coords.len)
	// 	for all the cables:
	// 	cable.x  cable.y
	// wire's state array
	//
	// i64(app.forced_states.len)
	// forced_states ([2]u32)
	//
	// i64(app.colorchips.len)
	// for each cc:
	// 	x, y, w, h
	//	i64(cc.colors.len)
	//	colors gg.Color r g b
	//	i64(cc.inputs.len)
	//	inputs [2]u32

	mut file := os.open_file(maps_path + map_name, 'w') or {
		app.log('${@LOCATION}: ${err}')
		return
	}
	defer {
		file.close()
	}
	dump('file opened')
	mut offset := u64(0)
	save_version := u32(0) // must be careful when V changes of int size, especially for array lenghts
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
	offset += sizeof(app.actual_state) // int
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
	unsafe {
		file.write_ptr_at(app.w_states[app.actual_state].data, app.diodes.len * int(sizeof(bool)),
			offset)
	}
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

fn (mut app App) load_gate_to_copied(gate_name string) ! {
	mut f := os.open(gates_path + gate_name)!
	mut read_n := u32(0)
	size := os.inode(gates_path + gate_name).size
	app.copied = []
	mut place := PlaceInstruction{}
	for read_n * sizeof(PlaceInstruction) < size {
		f.read_struct_at(mut place, read_n * sizeof(PlaceInstruction))!
		app.copied << place
		read_n += 1
	}
	f.close()
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

fn (mut app App) rotate_copied() {
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

// Will be used?
fn (mut app App) gate_unit_tests(x u32, y u32, square_size int) {
	size := u32(square_size) // we dont know the size of the gates that will be placed, 100 should be okay, same as below
	cycles := square_size // we dont know in how much cycles the bug will happen, needs to match the amount in the fuzz testing because the unit tests will come from there
	app.removal(x, y, x + size, y + size)
	gates: for gate_path in os.ls('test_gates/') or {
		app.log('Listing the test gates: ${err}')
		return
	} {
		app.load_gate_to_copied('test_gates/' + gate_path) or {
			app.log('FAIL: cant load the gate: test_gates/${gate_path}, ${err}')
			continue
		}
		app.paste(x, y)
		for _ in 0 .. cycles {
			app.update_cycle()
			x_err, y_err, str_err := app.test_validity(x, y, x + size, y + size)
			if str_err != '' {
				app.log('FAIL: (validity) ${str_err}')
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

fn (mut app App) test_validity(_x_start u32, _y_start u32, _x_end u32, _y_end u32) (u32, u32, string) {
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
	mut last_cm_x := x_start
	mut last_cm_y := y_start
	for x in x_start .. x_end + 1 {
		for y in y_start .. y_end + 1 {
				chunk_i = app.get_chunkmap_idx_at_coords(x, y)
			if check_change_chunkmap(last_cm_x, last_cm_y, x, y) {
				last_cm_x = x
				last_cm_y = y
			}
			mut chunkmap := &app.map[chunk_i].id_map
			x_map := x % chunk_size
			y_map := y % chunk_size
			id := unsafe { chunkmap[x_map][y_map] }
			if id == 0x0 { // map empty
				continue
			}
			if id == elem_crossing_bits { // same bits as wires so need to be separated
				continue // do not have any state to check
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
					inp_id := app.next_gate_id(x, y, -step[0], -step[1], ori)
					if inp_id & id_mask != app.get_input(id) & id_mask {
						return x, y, 'problem: Not/Diode input is not the preceding gate ${inp_id & id_mask:b} != ${app.get_input(id) & id_mask:b}'
					}
					inp_old_state, _ := app.get_elem_state_idx_by_id(inp_id, 1)
					if id & elem_type_mask == elem_not_bits {
						state, _ := app.get_elem_state_idx_by_id(id, 0)
						if state == inp_old_state {
							return x, y, 'problem: NOT did not inverse the input state ${state} ${inp_old_state}'
						}
						if (id & on_bits != 0) == inp_old_state {
							return x, y, 'problem: NOT(map state) did not inverse the input state'
						}
					} else { // diode
						state, _ := app.get_elem_state_idx_by_id(id, 0)
						if state != inp_old_state {
							return x, y, 'problem: Diode did not match the input state'
						}
						if (id & on_bits != 0) != inp_old_state {
							return x, y, 'problem: Diode(map state) did not match the input state'
						}
					}
				}
				elem_on_bits { // do not have any state to check
				}
				elem_wire_bits {
					s_adj_id, s_is_input, _, _ := app.wire_next_gate_id_coo(x, y, 0, 1)
					n_adj_id, n_is_input, _, _ := app.wire_next_gate_id_coo(x, y, 0, -1)
					e_adj_id, e_is_input, _, _ := app.wire_next_gate_id_coo(x, y, 1, 0)
					w_adj_id, w_is_input, _, _ := app.wire_next_gate_id_coo(x, y, -1, 0)
					wire_state, wire_idx := app.get_elem_state_idx_by_id(id, 0)
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
								s_old_state, _ := app.get_elem_state_idx_by_id(s_adj_id, 1)
								if s_old_state && !wire_state {
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
								n_old_state, _ := app.get_elem_state_idx_by_id(n_adj_id, 1)
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
								e_old_state, _ := app.get_elem_state_idx_by_id(e_adj_id, 1)
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
								w_old_state, _ := app.get_elem_state_idx_by_id(w_adj_id, 1)
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

fn (mut app App) fuzz(_x_start u32, _y_start u32, _x_end u32, _y_end u32, seed []u32) {
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
	for x in x_start .. x_end {
		for y in y_start .. y_end {
			app.selected_ori = match rand.int_in_range(0, 4) or { 0 } {
				1 { north }
				2 { south }
				3 { east }
				else { west }
			}
			match rand.int_in_range(0, 6) or { 0 } {
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
		}
	}
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

	for x in x_start .. x_end + 1 {
		for y in y_start .. y_end + 1 {
			chunk_i := app.get_chunkmap_idx_at_coords(x, y)
			mut chunkmap := &app.map[chunk_i].id_map
			x_map := x % chunk_size
			y_map := y % chunk_size
			id := unsafe { chunkmap[x_map][y_map] }
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

	for x in x_start .. x_end + 1 {
		for y in y_start .. y_end + 1 {
			chunk_i := app.get_chunkmap_idx_at_coords(x, y)
			mut chunkmap := &app.map[chunk_i].id_map
			x_map := x % chunk_size
			y_map := y % chunk_size
			id := unsafe { chunkmap[x_map][y_map] }
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
					chunkmap[x_map][y_map] = empty_id
				}
				// 2. done: no state & no struct

				// 3. done
				s_adj_id, s_is_input, _, s_y_off := app.wire_next_gate_id_coo(x, y, 0,
					1)
				n_adj_id, n_is_input, _, n_y_off := app.wire_next_gate_id_coo(x, y, 0,
					-1)
				e_adj_id, e_is_input, e_x_off, _ := app.wire_next_gate_id_coo(x, y, 1,
					0)
				w_adj_id, w_is_input, w_x_off, _ := app.wire_next_gate_id_coo(x, y, -1,
					0)
				if s_adj_id != empty_id && n_adj_id != empty_id {
					if s_adj_id & elem_type_mask == elem_wire_bits
						&& n_adj_id & elem_type_mask == elem_wire_bits {
						// two wires: separate them
						app.separate_wires([[x, u32(y + n_y_off)]!,
							[u32(x), u32(y + s_y_off)]!], s_adj_id) // same id for north and south
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
				if e_adj_id != empty_id && w_adj_id != empty_id {
					if e_adj_id & elem_type_mask == elem_wire_bits
						&& w_adj_id & elem_type_mask == elem_wire_bits {
						// two wires: separate them
						app.separate_wires([[u32(x + w_x_off), y]!,
							[u32(x + e_x_off), y]!], e_adj_id) // same id for east and west
					} else if e_adj_id & elem_type_mask == elem_wire_bits {
						// one side is a wire: add the new i/o for the wire & for the gate
						if w_is_input {
							app.remove_input(e_adj_id, w_adj_id)
							// not the wire -> not useful app.remove_output(w_adj_id, e_adj_id) // remove output of the gate
						} else {
							app.remove_output(e_adj_id, w_adj_id)
							app.remove_input(w_adj_id, e_adj_id) // remove output of the gate
						}
					} else if w_adj_id & elem_type_mask == elem_wire_bits {
						// one side is a wire: add the new i/o for the wire & for the gate
						if e_is_input {
							app.remove_input(w_adj_id, e_adj_id)
							// not the wire -> not useful app.remove_output(e_adj_id, w_adj_id) // remove output of the gate
						} else {
							app.remove_output(w_adj_id, e_adj_id)
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
						chunkmap[x_map][y_map] = empty_id
					}
					// 2. done
					_, idx := app.get_elem_state_idx_by_id(id, 0)
					app.nots.delete(idx)
					app.n_states[0].delete(idx)
					app.n_states[1].delete(idx)

					// 3. done
					inp_id := app.next_gate_id(x, y, -x_ori, -y_ori, id & ori_mask)
					out_id := app.next_gate_id(x, y, x_ori, y_ori, id & ori_mask)
					app.remove_input(out_id, id)
					app.remove_output(inp_id, id)
				}
				elem_diode_bits {
					// 1. done
					unsafe {
						chunkmap[x_map][y_map] = empty_id
					}
					// 2. done
					_, idx := app.get_elem_state_idx_by_id(id, 0)
					app.diodes.delete(idx)
					app.d_states[0].delete(idx)
					app.d_states[1].delete(idx)

					// 3. done
					inp_id := app.next_gate_id(x, y, -x_ori, -y_ori, id & ori_mask)
					out_id := app.next_gate_id(x, y, x_ori, y_ori, id & ori_mask)
					app.remove_input(out_id, id)
					app.remove_output(inp_id, id)
				}
				elem_on_bits {
					// 1. done
					unsafe {
						chunkmap[x_map][y_map] = empty_id
					}
					// 2. done
					// no arrays for the ons

					// 3. done; only an input for other elements
					out_id := app.next_gate_id(x, y, x_ori, y_ori, id & ori_mask)
					app.remove_input(out_id, id)
				}
				elem_wire_bits {
					// Find if a part of an existing wire
					mut coo_adj_wire := [][2]u32{}
					mut adjacent_inps := []u64{}
					mut adjacent_outs := []u64{}
					for coo in [[0, 1], [0, -1], [1, 0], [-1, 0]] {
						adj_id, is_input, x_off, y_off := app.wire_next_gate_id_coo(x,
							y, coo[0], coo[1])
						assert adj_id != elem_crossing_bits
						if adj_id == empty_id {
						} else if adj_id & elem_type_mask == elem_wire_bits {
							coo_adj_wire << [u32(int(x) + x_off), u32(int(y) + y_off)]!
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
						chunkmap[x_map][y_map] = empty_id
					}
					// 2. done
					// Separate the wires:
					if coo_adj_wire.len > 1 {
						app.separate_wires(coo_adj_wire, id)
					} else if coo_adj_wire.len == 0 {
						_, idx := app.get_elem_state_idx_by_id(id, 0)
						app.wires.delete(idx)
						app.w_states[0].delete(idx)
						app.w_states[1].delete(idx)
					} else { // if only 1 adjacent wire: remove the cable from the wire
						_, idx := app.get_elem_state_idx_by_id(id, 0)
						i := app.wires[idx].cable_coords.index([x, y]!)
						app.wires[idx].cable_coords.delete(i)
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
fn (mut app App) separate_wires(coo_adj_wires [][2]u32, id u64) {
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
	mut new_wires := []Wire{len: coo_adj_wires.len, init: Wire{
		rid:          u64(index)
		cable_coords: [[coo_adj_wires[index][0], coo_adj_wires[index][1]]!]
	}}
	mut c_stack := [][2]u32{len: coo_adj_wires.len, init: coo_adj_wires[index]}
	mut id_stack := []u64{len: coo_adj_wires.len, init: u64(index)}

	cable_stack: for c_stack.len > 0 { // for each wire in the stack
		cable := c_stack.pop()
		cable_id := id_stack.pop()
		for w in new_wires {
			if w.rid != cable_id {
				if cable in w.cable_coords {
					continue cable_stack // cable was already processed and the id is outdated
				}
			}
		}
		for coo in [[0, 1], [0, -1], [1, 0], [-1, 0]] { // for each adjacent tile
			adj_id, is_input, x_off, y_off := app.wire_next_gate_id_coo(cable[0], cable[1],
				coo[0], coo[1])
			if adj_id != empty_id {
				total_x := u32(i64(cable[0]) + x_off)
				total_y := u32(i64(cable[1]) + y_off)
				chunk_i := app.get_chunkmap_idx_at_coords(total_x, total_y)
				mut adj_chunkmap := &app.map[chunk_i].id_map
				adj_x_map := total_x % chunk_size
				adj_y_map := total_y % chunk_size
				assert adj_id == unsafe { adj_chunkmap[adj_x_map][adj_y_map] }
				if adj_id & elem_type_mask == elem_wire_bits { // if is a wire
					adj_coo := [total_x, total_y]!
					mut wid_adj := which_wire(new_wires, adj_coo) // will be the id of the wire in which the actual adj cable is
					if wid_adj == u64(-1) { // if the coord is not already in a wire list
						for mut wire in new_wires { // find the wire where cable is
							if wire.rid == cable_id {
								wid_adj = cable_id
								wire.cable_coords << adj_coo // the rest of this wire will get processed
								// no need remove it from it's actual wire because it is already done in the modifications in the end
							}
						}
						if wid_adj == u64(-1) {
							app.log_quit('${@LOCATION} should have found the appropriate wire')
						}
					} else {
						if wid_adj != cable_id { // if is in a list but not the same as cable
							// merge the lists
							// get the two lists
							mut i_first := -1
							mut i_sec := -1
							for iw, wire in new_wires {
								if wire.rid == cable_id {
									i_first = iw
								} else if wire.rid == wid_adj {
									i_sec = iw
								}
							}
							wid_adj = cable_id
							// merge
							new_wires[i_first].cable_coords << new_wires[i_sec].cable_coords
							new_wires[i_first].inps << new_wires[i_sec].inps
							new_wires[i_first].outs << new_wires[i_sec].outs
							for mut ids in id_stack {
								if ids == i_sec {
									ids = u64(i_first)
								}
							}
							new_wires.delete(i_sec)
						} else {
							continue // was already processed
						}
					}
					// put the actual adj cable on the stack
					c_stack << adj_coo
					id_stack << wid_adj
				} else {
					// it is an input or an output, or else the wire_next_gate_id_coo function would have returned empty_id
					for mut wire in new_wires { // find the wire where cable is
						if wire.rid == cable_id {
							if is_input {
								wire.inps << adj_id
							} else {
								wire.outs << adj_id
							}
						}
					}
				}
			}
		}
	}

	// Create/Modify the new wires
	_, idx := app.get_elem_state_idx_by_id(id, 0)
	new_wires[0].rid = id & rid_mask
	app.wires[idx] = new_wires[0]
	state0 := app.w_states[0][idx]
	state1 := app.w_states[1][idx]
	for mut wire in new_wires[1..] {
		wire.rid = app.w_next_rid
		app.wires << wire
		app.w_states[0] << state0
		app.w_states[1] << state1
		app.w_next_rid++
	}

	// change the ids of the cables on the map and the I/O's i/o (actual I/O of the new wires)
	for wire in new_wires {
		for coo in wire.cable_coords {
			chunk_i := app.get_chunkmap_idx_at_coords(coo[0], coo[1])
			mut adj_chunkmap := &app.map[chunk_i].id_map
			adj_x_map := coo[0] % chunk_size
			adj_y_map := coo[1] % chunk_size
			unsafe {
				adj_chunkmap[adj_x_map][adj_y_map] &= on_bits // keep the state
				adj_chunkmap[adj_x_map][adj_y_map] |= wire.rid | elem_wire_bits // add the new id
			}
		}

		for inp in wire.inps {
			app.add_output(inp, wire.rid | elem_wire_bits)
		}
		for out in wire.outs {
			app.add_input(out, wire.rid | elem_wire_bits)
		}
	}
}

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
	// 4.
	// add one to the rid of the type

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
			for x in x_start .. x_end + 1 {
				for y in y_start .. y_end + 1 {
					chunk_i := app.get_chunkmap_idx_at_coords(x, y)
					mut chunkmap := &app.map[chunk_i].id_map
					x_map := x % chunk_size
					y_map := y % chunk_size
					if unsafe { chunkmap[x_map][y_map] } != empty_id { // map not empty
						continue
					}

					// 1. done
					id := elem_not_bits | app.n_next_rid | app.selected_ori
					unsafe {
						chunkmap[x_map][y_map] = id
					}
					// 2. done
					inp_id := app.next_gate_id(x, y, -x_ori, -y_ori, id & ori_mask)
					app.nots << Nots{id & rid_mask, inp_id, x, y}
					app.n_states[0] << false // default state & important to do the two lists
					app.n_states[1] << false // default state

					// 3. done
					out_id := app.next_gate_id(x, y, x_ori, y_ori, id & ori_mask)
					app.add_input(out_id, id)
					app.add_output(inp_id, id)

					// 4. done
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
					if unsafe { chunkmap[x_map][y_map] } != empty_id { // map not empty
						continue
					}

					// 1. done
					id := elem_diode_bits | app.d_next_rid | app.selected_ori
					unsafe {
						chunkmap[x_map][y_map] = id
					}
					// 2. done
					inp_id := app.next_gate_id(x, y, -x_ori, -y_ori, id & ori_mask)
					app.diodes << Diode{id & rid_mask, inp_id, x, y}
					app.d_states[0] << false // default state & important to do the two lists
					app.d_states[1] << false // default state

					// 3. done
					out_id := app.next_gate_id(x, y, x_ori, y_ori, id & ori_mask)
					app.add_input(out_id, id)
					app.add_output(inp_id, id)

					// 4. done
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
					if unsafe { chunkmap[x_map][y_map] } != empty_id { // map not empty
						continue
					}

					// 1. done
					id := elem_on_bits | on_bits | app.selected_ori
					unsafe {
						chunkmap[x_map][y_map] = id
					}
					// 2. done
					// no arrays for the ons

					// 3. done; only an input for other elements
					out_id := app.next_gate_id(x, y, x_ori, y_ori, id & ori_mask)
					app.add_input(out_id, id)

					// 4. done, no need
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
					if unsafe { chunkmap[x_map][y_map] } != empty_id { // map not empty
						continue
					}
					// Find if a part of an existing wire
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
						app.wires << Wire{
							rid: app.w_next_rid
						}
						adjacent_wires << app.w_next_rid | elem_wire_bits
						app.w_states[0] << false
						app.w_states[1] << false
						// 4. done /!\ only if creating a new wire
						app.w_next_rid++
					}
					_, first_i := app.get_elem_state_idx_by_id(adjacent_wires[0], 0)

					// 1. done
					unsafe {
						if app.w_states[app.actual_state][first_i] {
							chunkmap[x_map][y_map] = elem_wire_bits | adjacent_wires[0] | on_bits
						} else {
							chunkmap[x_map][y_map] = elem_wire_bits | adjacent_wires[0]
						}
					} // no orientation

					// 2. done
					app.wires[first_i].cable_coords << [x, y]!
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
			for x in x_start .. x_end + 1 {
				for y in y_start .. y_end + 1 {
					chunk_i := app.get_chunkmap_idx_at_coords(x, y)
					mut chunkmap := &app.map[chunk_i].id_map
					x_map := x % chunk_size
					y_map := y % chunk_size
					if unsafe { chunkmap[x_map][y_map] } != empty_id { // map not empty
						continue
					}
					// 1. done; they all have the same id
					unsafe {
						chunkmap[x_map][y_map] = elem_crossing_bits
					}
					// 2. done: no state & no struct

					// 3. done
					s_adj_id, s_is_input, _, _ := app.wire_next_gate_id_coo(x, y, 0, 1)
					n_adj_id, n_is_input, _, _ := app.wire_next_gate_id_coo(x, y, 0, -1)
					e_adj_id, e_is_input, _, _ := app.wire_next_gate_id_coo(x, y, 1, 0)
					w_adj_id, w_is_input, _, _ := app.wire_next_gate_id_coo(x, y, -1,
						0)
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
	adjacent_wires.sort() // the id order is the same as the idx order so no problem for deletion
	_, first_i := app.get_elem_state_idx_by_id(adjacent_wires[0], 0)
	for wire in adjacent_wires[1..] { // find the state
		_, i := app.get_elem_state_idx_by_id(wire, 0)
		app.w_states[app.actual_state][first_i] = app.w_states[app.actual_state][first_i]
			|| app.w_states[app.actual_state][i]
	}
	state := app.w_states[app.actual_state][first_i]
	if state { // update the first wire's state
		for coo in app.wires[first_i].cable_coords {
			// change the id of all the cables on the map
			chunk_i := app.get_chunkmap_idx_at_coords(coo[0], coo[1])
			mut w_chunkmap := &app.map[chunk_i].id_map
			unsafe {
				w_chunkmap[coo[0] % chunk_size][coo[1] % chunk_size] |= on_bits
			}
		}
	}
	// join the other wires with the first one
	for wire in adjacent_wires[1..] {
		_, i := app.get_elem_state_idx_by_id(wire, 0)
		for coo in app.wires[i].cable_coords {
			// change the id of all the cables on the map
			chunk_i := app.get_chunkmap_idx_at_coords(coo[0], coo[1])
			mut w_chunkmap := &app.map[chunk_i].id_map
			unsafe {
				if state {
					w_chunkmap[coo[0] % chunk_size][coo[1] % chunk_size] = adjacent_wires[0] | on_bits
				} else {
					w_chunkmap[coo[0] % chunk_size][coo[1] % chunk_size] = adjacent_wires[0]
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
		app.wires[first_i].inps << app.wires[i].inps
		app.wires[first_i].outs << app.wires[i].outs
		// delete the old wires
		app.wires.delete(i)
		app.w_states[0].delete(i)
		app.w_states[1].delete(i)
	}
}

// get the input of the elem (empty_id for wires & ons)
fn (mut app App) get_input(elem_id u64) u64 {
	if elem_id != empty_id && elem_id != elem_crossing_bits {
		if elem_id & elem_type_mask == elem_not_bits { // not
			_, idx := app.get_elem_state_idx_by_id(elem_id, 0) // do not want the state
			return app.nots[idx].inp
		} else if elem_id & elem_type_mask == elem_diode_bits { // diode
			_, idx := app.get_elem_state_idx_by_id(elem_id, 0) // do not want the state
			return app.diodes[idx].inp
		} else if elem_id & elem_type_mask == elem_on_bits { // on -> does not have inputs
		} else if elem_id & elem_type_mask == elem_wire_bits { // wire
		}
	}
	return empty_id
}

// add input_id to the input(s) of elem_id (if it is a valid id)
fn (mut app App) add_input(elem_id u64, input_id u64) {
	if elem_id != empty_id && elem_id != elem_crossing_bits {
		_, idx := app.get_elem_state_idx_by_id(elem_id, 0) // do not want the state
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
		_, idx := app.get_elem_state_idx_by_id(elem_id, 0) // do not want the state
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
			_, idx := app.get_elem_state_idx_by_id(elem_id, 0) // do not want the state
			app.wires[idx].outs << output_id
		}
	}
}

fn (mut app App) remove_output(elem_id u64, output_id u64) {
	if elem_id != empty_id && elem_id != elem_crossing_bits {
		if elem_id & elem_type_mask == elem_wire_bits { // wire
			_, idx := app.get_elem_state_idx_by_id(elem_id, 0) // do not want the state
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
	mut next_id := unsafe { next_chunkmap[conv_x % chunk_size][conv_y % chunk_size] }
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
				chunk_i = app.get_chunkmap_idx_at_coords(x_conv, y_conv)
			if check_change_chunkmap(last_cm_x, last_cm_y, x_conv, y_conv) {
				last_cm_x = x_conv
				last_cm_y = y_conv
			}
			next_chunkmap = &app.map[chunk_i].id_map
			next_id = unsafe { next_chunkmap[x_conv % chunk_size][y_conv % chunk_size] }
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
	mut next_chunkmap := &app.map[chunk_i].id_map
	mut next_id := unsafe { next_chunkmap[conv_x % chunk_size][conv_y % chunk_size] }
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
			chunk_i = app.get_chunkmap_idx_at_coords(x_conv, y_conv)
			next_chunkmap = &app.map[chunk_i].id_map
			next_id = unsafe { next_chunkmap[x_conv % chunk_size][y_conv % chunk_size] }
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

fn (mut app App) set_elem_state_by_pos(x u32, y u32, new_state bool) {
	chunk_i := app.get_chunkmap_idx_at_coords(x, y)
	mut chunkmap := &app.map[chunk_i].id_map
	xmap := x % chunk_size
	ymap := y % chunk_size
	id := unsafe { chunkmap[xmap][ymap] }
	if id == elem_crossing_bits || id == empty_id || id & elem_type_mask == elem_on_bits {
		return
	}
	if new_state {
		unsafe {
			chunkmap[xmap][ymap] = chunkmap[xmap][ymap] | on_bits
		}
	} else {
		unsafe {
			chunkmap[xmap][ymap] = chunkmap[xmap][ymap] & (~on_bits)
		}
	}
	_, i := app.get_elem_state_idx_by_id(unsafe { chunkmap[xmap][ymap] }, 0)
	if id & elem_type_mask == elem_wire_bits {
		app.w_states[app.actual_state][i] = new_state
	} else if id & elem_type_mask == elem_not_bits {
		app.n_states[app.actual_state][i] = new_state
	} else if id & elem_type_mask == elem_diode_bits {
		app.d_states[app.actual_state][i] = new_state
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
		// 3. done
		old_inp_state, _ := app.get_elem_state_idx_by_id(not.inp, 1)
		// 4. done
		app.n_states[app.actual_state][i] = !old_inp_state
		chunk_i := app.get_chunkmap_idx_at_coords(not.x, not.y)
		mut chunkmap := &app.map[chunk_i].id_map
		xmap := not.x % chunk_size
		ymap := not.y % chunk_size
		if !old_inp_state {
			unsafe {
				chunkmap[xmap][ymap] = chunkmap[xmap][ymap] | on_bits
			}
		} else {
			unsafe {
				chunkmap[xmap][ymap] = chunkmap[xmap][ymap] & (~on_bits)
			}
		}
	}
	for i, diode in app.diodes {
		// 3. done
		old_inp_state, _ := app.get_elem_state_idx_by_id(diode.inp, 1)
		// 4. done
		app.d_states[app.actual_state][i] = old_inp_state
		chunk_i := app.get_chunkmap_idx_at_coords(diode.x, diode.y)
		mut chunkmap := &app.map[chunk_i].id_map
		xmap := diode.x % chunk_size
		ymap := diode.y % chunk_size
		if old_inp_state {
			unsafe {
				chunkmap[xmap][ymap] = chunkmap[xmap][ymap] | on_bits
			}
		} else {
			unsafe {
				chunkmap[xmap][ymap] = chunkmap[xmap][ymap] & (~on_bits)
			}
		}
	}
	for i, wire in app.wires {
		// 3. done
		mut old_or_inp_state := false // will be all the inputs of the wire ORed
		for inp in wire.inps {
			old_inp_state, _ := app.get_elem_state_idx_by_id(inp, 1)
			if old_inp_state {
				old_or_inp_state = true // only one is needed for the OR to be true
				break
			}
		}
		// 4. done
		app.w_states[app.actual_state][i] = old_or_inp_state
		for cable_coo in wire.cable_coords {
			chunk_i := app.get_chunkmap_idx_at_coords(cable_coo[0], cable_coo[1])
			mut chunkmap := &app.map[chunk_i].id_map
			xmap := cable_coo[0] % chunk_size
			ymap := cable_coo[1] % chunk_size
			if old_or_inp_state {
				unsafe {
					chunkmap[xmap][ymap] = chunkmap[xmap][ymap] | on_bits
				}
			} else {
				unsafe {
					chunkmap[xmap][ymap] = chunkmap[xmap][ymap] & (~on_bits)
				}
			}
		}
	}
}

@[inline]
fn check_change_chunkmap(x u32, y u32, x1 u32, y1 u32) bool {
	return (x / chunk_size) * chunk_size != (x1 / chunk_size) * chunk_size || (y / chunk_size) * chunk_size != (y1 / chunk_size) * chunk_size
}

fn (mut app App) get_chunkmap_idx_at_coords(x u32, y u32) int {
	x_ := (x / chunk_size) * chunk_size
	y_ := (y / chunk_size) * chunk_size
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
			x: x_
			y: y_
		}
		app.chunk_cache[coo] = app.map.len - 1
		app.map.len - 1
	}
}

// previous: 0 for actual state, 1 for the previous state
// returns the state of the concerned element & the index in the list
// crossing & ons dont have different states nor idx
fn (mut app App) get_elem_state_idx_by_id(id u64, previous int) (bool, int) {
	concerned_state := (app.actual_state + previous) % 2
	rid := id & rid_mask
	// the state in the id may be an old state so it needs to get the state from the state lists
	if id == empty_id {
		return false, -1
	}
	if id & elem_type_mask == elem_on_bits { // on
		return true, -1
	} else if id & elem_type_mask == elem_not_bits { // not
		mut low := 0
		mut high := app.nots.len - 1
		mut mid := 0 // tmp value
		for low <= high {
			mid = low + ((high - low) >> 1) // low + half
			// If x is smaller, ignore left half
			if app.nots[mid].rid < rid {
				low = mid + 1
			}
			// If x greater, ignore right half
			else if app.nots[mid].rid > rid {
				high = mid - 1
			}
			// Check if x is present at mid
			else {
				return app.n_states[concerned_state][mid], mid
			}
		}
		dump(app.nots)
	} else if id & elem_type_mask == elem_diode_bits { // diode
		mut low := 0
		mut high := app.diodes.len - 1
		mut mid := 0 // tmp value
		for low <= high {
			mid = low + ((high - low) >> 1) // low + half
			if app.diodes[mid].rid < rid {
				low = mid + 1
			} else if app.diodes[mid].rid > rid {
				high = mid - 1
			} else {
				return app.d_states[concerned_state][mid], mid
			}
		}
		dump(app.diodes)
	} else if id & elem_type_mask == elem_wire_bits { // wire
		mut low := 0
		mut high := app.wires.len - 1
		mut mid := 0 // tmp value
		for low <= high {
			mid = low + ((high - low) >> 1) // low + half
			if app.wires[mid].rid < rid {
				low = mid + 1
			} else if app.wires[mid].rid > rid {
				high = mid - 1
			} else {
				return app.w_states[concerned_state][mid], mid
			}
		}
		dump(app.wires)
	}
	app.log_quit('${@LOCATION} id not found in get_elem_state_idx_by_id: ${id & rid_mask}')
}

// TODO: Explain ids
// RIDs are pure rids (the number of the gate in it's type)
// pure id: rid | elem_type_bits
// others ids like inp out, are unpure ids by default (assume they are) -> if you want it's id without state/orientation -> & id_mask, if you want it's rid -> & rid_mask

// An element is a something placed on the map (so not empty)
// A gate is an element with some inputs or some outputs or both
// The orientation of a gate is where the output is facing

// Crossing: a special element that links it's north & south sides and (separately) it's west and east sides as if it was not there
// Example: a not gate facing west placed next to a crossing (the not gate is on it's west side), will have as input the element placed next to the crossing on the east side

struct Chunk {
mut:
	x      u32
	y      u32
	id_map [chunk_size][chunk_size]u64 // [x][y] x++=east y++=south
}

// A gate that outputs the opposite of the input signal
struct Nots {
	rid u64 // real id
mut:
	inp u64 // id of the input element of the not gate
	// Map coordinates
	x u32
	y u32
}

// A gate that transmit the input signal to the output element (unidirectionnal) and adds 1 tick delay (1 update cycle to update)
struct Diode {
	rid u64 // real id
mut:
	inp u64 // id of the input element of the not gate
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
	rid          u64      // real id
	inps         []u64    // id of the input elements outputing to the wire
	outs         []u64    // id of the output elements whose inputs are the wire
	cable_coords [][2]u32 // all the x y coordinates of the induvidual cables (elements) the wire is made of
}
